const std = @import("std");
const net = std.net;
const mem = std.mem;
const json = std.json;

pub const Item = struct {
    id: []const u8,
    name: []const u8,
    description: ?[]const u8 = null,
    created_at: []const u8,
};

pub const CreateItemRequest = struct {
    name: []const u8,
    description: ?[]const u8 = null,
};

pub const AppState = struct {
    allocator: mem.Allocator,
    mutex: std.Thread.Mutex = .{},
    items: std.StringHashMap(Item),
    next_id: std.atomic.Value(u64) = std.atomic.Value(u64).init(1),
    request_count: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),

    pub fn init(allocator: mem.Allocator) AppState {
        return .{
            .allocator = allocator,
            .items = std.StringHashMap(Item).init(allocator),
        };
    }

    pub fn deinit(self: *AppState) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        var it = self.items.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.name);
            if (entry.value_ptr.description) |d| self.allocator.free(d);
            self.allocator.free(entry.value_ptr.created_at);
        }
        self.items.deinit();
    }

    pub fn logRequest(method: []const u8, path: []const u8) void {
        const stdout = std.io.getStdOut().writer();
        stdout.print("{{\"level\":\"INFO\",\"msg\":\"http_request\",\"method\":\"{s}\",\"path\":\"{s}\"}}\n", .{ method, path }) catch {};
    }

    pub fn handleRequest(self: *AppState, method: []const u8, path: []const u8, body: []const u8, response_buf: *std.ArrayList(u8)) !void {
        _ = self.request_count.fetchAdd(1, .monotonic);
        logRequest(method, path);

        const writer = response_buf.writer();

        if (mem.eql(u8, method, "GET") and mem.eql(u8, path, "/healthz")) {
            try writer.writeAll("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\n\r\n{\"status\":\"ok\"}");
        } else if (mem.eql(u8, method, "GET") and mem.eql(u8, path, "/readyz")) {
            try writer.writeAll("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\n\r\n{\"ready\":true}");
        } else if (mem.eql(u8, method, "GET") and mem.eql(u8, path, "/metrics")) {
            const count = self.request_count.load(.monotonic);
            try writer.print("HTTP/1.1 200 OK\r\nContent-Type: text/plain; version=0.0.4\r\nConnection: close\r\n\r\n# HELP http_requests_total Total number of HTTP requests\n# TYPE http_requests_total counter\nhttp_requests_total {}\n", .{count});
        } else if (mem.eql(u8, method, "GET") and mem.eql(u8, path, "/api/v1/items")) {
            self.mutex.lock();
            defer self.mutex.unlock();

            try writer.writeAll("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\n\r\n[");
            var it = self.items.iterator();
            var first = true;
            while (it.next()) |entry| {
                if (!first) try writer.writeByte(',');
                first = false;
                try json.stringify(entry.value_ptr.*, .{}, writer);
            }
            try writer.writeByte(']');
        } else if (mem.eql(u8, method, "POST") and mem.eql(u8, path, "/api/v1/items")) {
            const parsed = json.parseFromSlice(CreateItemRequest, self.allocator, body, .{}) catch {
                try writer.writeAll("HTTP/1.1 400 Bad Request\r\nContent-Type: application/json\r\nConnection: close\r\n\r\n{\"code\":400,\"message\":\"invalid request body\"}");
                return;
            };
            defer parsed.deinit();

            if (parsed.value.name.len == 0) {
                try writer.writeAll("HTTP/1.1 400 Bad Request\r\nContent-Type: application/json\r\nConnection: close\r\n\r\n{\"code\":400,\"message\":\"name is required\"}");
                return;
            }

            const id_val = self.next_id.fetchAdd(1, .monotonic);
            const id_str = try std.fmt.allocPrint(self.allocator, "{}", .{id_val});
            const name_copy = try self.allocator.dupe(u8, parsed.value.name);
            const desc_copy = if (parsed.value.description) |d| try self.allocator.dupe(u8, d) else null;
            const created_at = try self.allocator.dupe(u8, "2026-11-10T09:00:00Z");

            const item = Item{
                .id = id_str,
                .name = name_copy,
                .description = desc_copy,
                .created_at = created_at,
            };

            self.mutex.lock();
            try self.items.put(id_str, item);
            self.mutex.unlock();

            try writer.writeAll("HTTP/1.1 201 Created\r\nContent-Type: application/json\r\nConnection: close\r\n\r\n");
            try json.stringify(item, .{}, writer);
        } else if (mem.startsWith(u8, path, "/api/v1/items/")) {
            const id = path["/api/v1/items/".len..];
            if (mem.eql(u8, method, "GET")) {
                self.mutex.lock();
                const maybe_item = self.items.get(id);
                self.mutex.unlock();

                if (maybe_item) |item| {
                    try writer.writeAll("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\n\r\n");
                    try json.stringify(item, .{}, writer);
                } else {
                    try writer.writeAll("HTTP/1.1 404 Not Found\r\nContent-Type: application/json\r\nConnection: close\r\n\r\n{\"code\":404,\"message\":\"item not found\"}");
                }
            } else if (mem.eql(u8, method, "DELETE")) {
                self.mutex.lock();
                const removed = self.items.fetchRemove(id);
                self.mutex.unlock();

                if (removed) |kv| {
                    self.allocator.free(kv.key);
                    self.allocator.free(kv.value.name);
                    if (kv.value.description) |d| self.allocator.free(d);
                    self.allocator.free(kv.value.created_at);
                    try writer.writeAll("HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n");
                } else {
                    try writer.writeAll("HTTP/1.1 404 Not Found\r\nContent-Type: application/json\r\nConnection: close\r\n\r\n{\"code\":404,\"message\":\"item not found\"}");
                }
            } else {
                try writer.writeAll("HTTP/1.1 405 Method Not Allowed\r\nConnection: close\r\n\r\n");
            }
        } else {
            try writer.writeAll("HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n");
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var state = AppState.init(allocator);
    defer state.deinit();

    const port: u16 = 8080;
    const address = try net.Address.parseIp4("0.0.0.0", port);
    var listener = try address.listen(.{ .reuse_address = true });
    defer listener.deinit();

    std.debug.print("{{\"level\":\"INFO\",\"msg\":\"starting albench zig server\",\"port\":{}}}\n", .{port});

    var buf: [8192]u8 = undefined;
    while (true) {
        var conn = listener.accept() catch |err| {
            std.debug.print("accept error: {}\n", .{err});
            continue;
        };
        defer conn.stream.close();

        const bytes_read = conn.stream.read(&buf) catch continue;
        if (bytes_read == 0) continue;
        const req_data = buf[0..bytes_read];

        var lines = mem.splitSequence(u8, req_data, "\r\n");
        const first_line = lines.next() orelse continue;

        var tokens = mem.tokenizeScalar(u8, first_line, ' ');
        const method = tokens.next() orelse continue;
        const path = tokens.next() orelse continue;

        var body: []const u8 = "";
        if (mem.indexOf(u8, req_data, "\r\n\r\n")) |body_idx| {
            body = req_data[body_idx + 4 ..];
        }

        var response_list = std.ArrayList(u8).init(allocator);
        defer response_list.deinit();

        try state.handleRequest(method, path, body, &response_list);
        conn.stream.writeAll(response_list.items) catch {};
    }
}

test "zig appstate endpoints" {
    const allocator = std.testing.allocator;
    var state = AppState.init(allocator);
    defer state.deinit();

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    // 1. healthz
    try state.handleRequest("GET", "/healthz", "", &buf);
    try std.testing.expect(mem.indexOf(u8, buf.items, "200 OK") != null);
    try std.testing.expect(mem.indexOf(u8, buf.items, "{\"status\":\"ok\"}") != null);

    // 2. metrics
    buf.clearRetainingCapacity();
    try state.handleRequest("GET", "/metrics", "", &buf);
    try std.testing.expect(mem.indexOf(u8, buf.items, "http_requests_total") != null);

    // 3. create item
    buf.clearRetainingCapacity();
    const create_body = "{\"name\":\"test-widget\",\"description\":\"first zig item\"}";
    try state.handleRequest("POST", "/api/v1/items", create_body, &buf);
    try std.testing.expect(mem.indexOf(u8, buf.items, "201 Created") != null);
    try std.testing.expect(mem.indexOf(u8, buf.items, "\"name\":\"test-widget\"") != null);

    // 4. get item
    buf.clearRetainingCapacity();
    try state.handleRequest("GET", "/api/v1/items/1", "", &buf);
    try std.testing.expect(mem.indexOf(u8, buf.items, "200 OK") != null);
    try std.testing.expect(mem.indexOf(u8, buf.items, "\"id\":\"1\"") != null);

    // 5. delete item
    buf.clearRetainingCapacity();
    try state.handleRequest("DELETE", "/api/v1/items/1", "", &buf);
    try std.testing.expect(mem.indexOf(u8, buf.items, "204 No Content") != null);
}
