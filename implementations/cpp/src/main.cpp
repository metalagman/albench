#include <iostream>
#include <string>
#include <unordered_map>
#include <shared_mutex>
#include <atomic>
#include <chrono>
#include "httplib.h"
#include "nlohmann/json.hpp"

using json = nlohmann::json;

struct Item {
    std::string id;
    std::string name;
    std::string description;
    std::string created_at;
};

void to_json(json& j, const Item& p) {
    j = json{{"id", p.id}, {"name", p.name}, {"created_at", p.created_at}};
    if (!p.description.empty()) {
        j["description"] = p.description;
    }
}

class Service {
public:
    std::shared_mutex mu;
    std::unordered_map<std::string, Item> items;
    std::atomic<uint64_t> next_id{1};
    std::atomic<uint64_t> request_count{0};

    void log_request(const std::string& method, const std::string& path, double duration_ms) {
        json log_entry = {
            {"level", "INFO"},
            {"msg", "http_request"},
            {"method", method},
            {"path", path},
            {"duration_ms", duration_ms}
        };
        std::cout << log_entry.dump() << "\n";
    }

    void setup_routes(httplib::Server& svr) {
        svr.Get("/healthz", [this](const httplib::Request&, httplib::Response& res) {
            auto start = std::chrono::steady_clock::now();
            request_count++;
            res.set_content(R"({"status":"ok"})", "application/json");
            auto duration = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count();
            log_request("GET", "/healthz", duration);
        });

        svr.Get("/readyz", [this](const httplib::Request&, httplib::Response& res) {
            auto start = std::chrono::steady_clock::now();
            request_count++;
            res.set_content(R"({"ready":true})", "application/json");
            auto duration = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count();
            log_request("GET", "/readyz", duration);
        });

        svr.Get("/metrics", [this](const httplib::Request&, httplib::Response& res) {
            request_count++;
            std::string body = "# HELP http_requests_total Total number of HTTP requests\n"
                               "# TYPE http_requests_total counter\n"
                               "http_requests_total " + std::to_string(request_count.load()) + "\n";
            res.set_content(body, "text/plain; version=0.0.4");
        });

        svr.Get("/api/v1/items", [this](const httplib::Request&, httplib::Response& res) {
            auto start = std::chrono::steady_clock::now();
            request_count++;
            json list = json::array();
            {
                std::shared_lock lock(mu);
                for (const auto& [_, item] : items) {
                    list.push_back(item);
                }
            }
            res.set_content(list.dump(), "application/json");
            auto duration = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count();
            log_request("GET", "/api/v1/items", duration);
        });

        svr.Post("/api/v1/items", [this](const httplib::Request& req, httplib::Response& res) {
            auto start = std::chrono::steady_clock::now();
            request_count++;
            try {
                auto body = json::parse(req.body);
                if (!body.contains("name") || body["name"].get<std::string>().empty()) {
                    res.status = 400;
                    res.set_content(R"({"code":400,"message":"name is required"})", "application/json");
                    return;
                }
                Item item;
                item.id = std::to_string(next_id++);
                item.name = body["name"].get<std::string>();
                if (body.contains("description")) {
                    item.description = body["description"].get<std::string>();
                }
                item.created_at = "2026-11-10T09:00:00Z";

                {
                    std::unique_lock lock(mu);
                    items[item.id] = item;
                }

                res.status = 201;
                res.set_content(json(item).dump(), "application/json");
            } catch (...) {
                res.status = 400;
                res.set_content(R"({"code":400,"message":"invalid json"})", "application/json");
            }
            auto duration = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count();
            log_request("POST", "/api/v1/items", duration);
        });

        svr.Get(R"(/api/v1/items/([^/]+))", [this](const httplib::Request& req, httplib::Response& res) {
            auto start = std::chrono::steady_clock::now();
            request_count++;
            std::string id = req.matches[1];
            Item item;
            bool found = false;
            {
                std::shared_lock lock(mu);
                auto it = items.find(id);
                if (it != items.end()) {
                    item = it->second;
                    found = true;
                }
            }
            if (found) {
                res.set_content(json(item).dump(), "application/json");
            } else {
                res.status = 404;
                res.set_content(R"({"code":404,"message":"item not found"})", "application/json");
            }
            auto duration = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count();
            log_request("GET", "/api/v1/items/" + id, duration);
        });

        svr.Delete(R"(/api/v1/items/([^/]+))", [this](const httplib::Request& req, httplib::Response& res) {
            auto start = std::chrono::steady_clock::now();
            request_count++;
            std::string id = req.matches[1];
            bool found = false;
            {
                std::unique_lock lock(mu);
                auto it = items.find(id);
                if (it != items.end()) {
                    items.erase(it);
                    found = true;
                }
            }
            if (found) {
                res.status = 204;
            } else {
                res.status = 404;
                res.set_content(R"({"code":404,"message":"item not found"})", "application/json");
            }
            auto duration = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count();
            log_request("DELETE", "/api/v1/items/" + id, duration);
        });
    }
};

#ifndef SERVER_TEST_BUILD
int main() {
    Service svc;
    httplib::Server svr;
    svc.setup_routes(svr);

    int port = 8080;
    std::cout << R"({"level":"INFO","msg":"starting albench cpp server","port":)" << port << "}\n";
    svr.listen("0.0.0.0", port);
    return 0;
}
#endif
