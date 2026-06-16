package com.lostmiracle.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
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
            } catch (Exception ignored) {
                SecurityContextHolder.clearContext();
            }
        }
        filterChain.doFilter(request, response);
    }

    private boolean isPublicAdminPath(HttpServletRequest request, String path) {
        return "POST".equalsIgnoreCase(request.getMethod()) && "/admin/auth/login".equals(path);
    }
}
