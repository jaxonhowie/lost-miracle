package com.lostmiracle.module.admin;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.lostmiracle.common.ErrorCode;
import com.lostmiracle.module.admin.GmRole;
import com.lostmiracle.module.admin.dto.GmLoginRequest;
import com.lostmiracle.module.admin.entity.GmAccountEntity;
import com.lostmiracle.module.admin.mapper.GmAccountMapper;
import com.lostmiracle.security.GmPrincipal;
import com.lostmiracle.support.IntegrationTestBase;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;
import java.util.Map;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
class AdminSecurityIntegrationTest extends IntegrationTestBase {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private AdminAuthService adminAuthService;

    @Autowired
    private GmAccountMapper gmAccountMapper;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void unauthenticatedAdminEndpoint_shouldReturn401() throws Exception {
        mockMvc.perform(get("/admin/auth/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value(ErrorCode.UNAUTHORIZED));
    }

    @Test
    void operatorPreviewFullSave_shouldReturnForbiddenBusinessCode() throws Exception {
        ensureOperatorAccount();
        TestUser player = createUser("gm_forbidden");
        var login = adminAuthService.login(new GmLoginRequest("operator_it", "operator-pass"));
        GmPrincipal operator = new GmPrincipal(
                login.gmAccountId(),
                login.username(),
                GmRole.fromString(login.role())
        );
        var operatorAuth = new UsernamePasswordAuthenticationToken(
                operator,
                null,
                List.of(new SimpleGrantedAuthority("ROLE_GM"))
        );

        mockMvc.perform(post("/admin/characters/{characterId}/save/preview", player.characterId())
                        .with(authentication(operatorAuth))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("player", Map.of("gold", 1)))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(ErrorCode.FORBIDDEN));
    }

    private void ensureOperatorAccount() {
        if (gmAccountMapper.selectByUsername("operator_it") != null) {
            return;
        }
        GmAccountEntity account = new GmAccountEntity();
        account.setUsername("operator_it");
        account.setPasswordHash(passwordEncoder.encode("operator-pass"));
        account.setRole(GmRole.operator.toDbValue());
        account.setStatus(1);
        gmAccountMapper.insert(account);
    }
}
