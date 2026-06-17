package com.lostmiracle.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

@Component
public class AdminJwtAuthFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(AdminJwtAuthFilter.class);

    private final AdminJwtTokenProvider adminJwtTokenProvider;

    public AdminJwtAuthFilter(AdminJwtTokenProvider adminJwtTokenProvider) {
        this.adminJwtTokenProvider = adminJwtTokenProvider;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        String path = request.getServletPath();
        if (!path.startsWith("/admin")) {
            filterChain.doFilter(request, response);
            return;
        }
        if (isPublicAdminPath(request, path)) {
            filterChain.doFilter(request, response);
            return;
        }

        // 如果已有认证（由其他 filter 设置），不覆盖
        if (SecurityContextHolder.getContext().getAuthentication() != null) {
            log.debug("admin filter: auth already set, skipping path={}", path);
            filterChain.doFilter(request, response);
            return;
        }

        String header = request.getHeader(HttpHeaders.AUTHORIZATION);
        if (header != null && header.startsWith("Bearer ")) {
            String token = header.substring(7);
            try {
                GmPrincipal principal = adminJwtTokenProvider.parseToken(token);
                var authentication = new UsernamePasswordAuthenticationToken(
                        principal,
                        null,
                        List.of(new SimpleGrantedAuthority("ROLE_GM"))
                );
                SecurityContextHolder.getContext().setAuthentication(authentication);
                log.debug("admin filter: set auth for gm={} path={}", principal.username(), path);
            } catch (Exception ex) {
                log.warn("admin filter: token parse failed path={} error={}", path, ex.getMessage());
                SecurityContextHolder.clearContext();
            }
        } else {
            log.debug("admin filter: no Bearer token, path={}", path);
        }
        filterChain.doFilter(request, response);
    }

    private boolean isPublicAdminPath(HttpServletRequest request, String path) {
        return "POST".equalsIgnoreCase(request.getMethod()) && "/admin/auth/login".equals(path);
    }
}
