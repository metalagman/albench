#define SERVER_TEST_BUILD
#include "../src/main.cpp"

#include <cassert>
#include <iostream>
#include <thread>

void run_tests() {
    Service svc;
    httplib::Server svr;
    svc.setup_routes(svr);

    int port = 18080;
    std::thread server_thread([&svr, port]() {
        svr.listen("127.0.0.1", port);
    });

    std::this_thread::sleep_for(std::chrono::milliseconds(100));

    httplib::Client cli("127.0.0.1", port);

    // 1. Healthz
    auto res = cli.Get("/healthz");
    assert(res && res->status == 200);

    // 2. Metrics
    res = cli.Get("/metrics");
    assert(res && res->status == 200);
    assert(res->body.find("http_requests_total") != std::string::npos);

    // 3. Create Item
    nlohmann::json req_body = {{"name", "test-cpp-widget"}, {"description", "first cpp item"}};
    res = cli.Post("/api/v1/items", req_body.dump(), "application/json");
    assert(res && res->status == 201);
    auto created = nlohmann::json::parse(res->body);
    assert(created["name"] == "test-cpp-widget");
    std::string id = created["id"];

    // 4. Get Item
    res = cli.Get("/api/v1/items/" + id);
    assert(res && res->status == 200);

    // 5. Delete Item
    res = cli.Delete("/api/v1/items/" + id);
    assert(res && res->status == 204);

    svr.stop();
    server_thread.join();
    std::cout << "All C++ endpoint tests passed successfully!\n";
}

int main() {
    run_tests();
    return 0;
}
