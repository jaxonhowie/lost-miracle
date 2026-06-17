package com.lostmiracle.security;

import com.lostmiracle.config.LostMiracleProperties;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

class JwtTokenProviderTest {

    private JwtTokenProvider provider;

    @BeforeEach
    void setUp() {
        LostMiracleProperties properties = new LostMiracleProperties();
        properties.getJwt().setSecret("change-me-to-a-long-random-secret-key-in-production");
        properties.getJwt().setExpirationSeconds(7200);
        provider = new JwtTokenProvider(properties);
    }

    @Test
    void createAndParseToken_shouldRoundTrip() {
        String token = provider.createToken(2066330095655710730L, "jwtdecode_test");

        UserPrincipal principal = provider.parseToken(token);

        assertNotNull(principal);
        assertEquals(2066330095655710730L, principal.userId());
        assertEquals("jwtdecode_test", principal.username());
    }
}
