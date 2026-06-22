package com.lostmiracle.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.lostmiracle.common.ApiResponse;
import com.lostmiracle.common.ErrorCode;
import com.lostmiracle.module.system.SystemSettingService;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

@Component
public class MaintenanceFilter extends OncePerRequestFilter {

    private final SystemSettingService systemSettingService;
    private final ObjectMapper objectMapper;

    public MaintenanceFilter(SystemSettingService systemSettingService, ObjectMapper objectMapper) {
        this.systemSettingService = systemSettingService;
        this.objectMapper = objectMapper;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        String path = request.getServletPath();

        // 放行 admin 和配置接口
        if (path.startsWith("/admin") || path.startsWith("/api/v1/config")) {
            filterChain.doFilter(request, response);
            return;
        }

        // 放行静态资源
        if (!path.startsWith("/api/v1/")) {
            filterChain.doFilter(request, response);
            return;
        }

        // 仅在玩家 API 路径上检查维护模式
        if (path.startsWith("/api/v1/auth") || path.startsWith("/api/v1/characters")) {
            if (systemSettingService.isMaintenanceMode()) {
                writeMaintenanceResponse(response);
                return;
            }
        }

        filterChain.doFilter(request, response);
    }

    private void writeMaintenanceResponse(HttpServletResponse response) throws IOException {
        response.setStatus(503);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");
        ApiResponse<Void> body = ApiResponse.fail(ErrorCode.SERVICE_UNAVAILABLE, systemSettingService.getMaintenanceMessage());
        response.getWriter().write(objectMapper.writeValueAsString(body));
    }
}
