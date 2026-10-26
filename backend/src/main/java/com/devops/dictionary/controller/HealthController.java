package com.devops.dictionary.controller;

import com.devops.dictionary.dto.ApiResponse;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import javax.sql.DataSource;
import java.sql.Connection;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/health")
public class HealthController {

    private final DataSource dataSource;

    public HealthController(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    @GetMapping
    public ResponseEntity<ApiResponse<Map<String, Object>>> checkHealth() {
        Map<String, Object> details = new HashMap<>();
        details.put("status", "UP");
        details.put("service", "dictionary-backend");
        details.put("version", "1.0.0");

        try (Connection conn = dataSource.getConnection()) {
            boolean valid = conn.isValid(2);
            details.put("database", valid ? "CONNECTED" : "UNREACHABLE");
        } catch (Exception e) {
            details.put("database", "DOWN: " + e.getMessage());
        }

        return ResponseEntity.ok(ApiResponse.success(details, "Application is healthy"));
    }
}
