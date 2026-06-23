package com.lostmiracle.config;

import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

class ProductionSafetyCheckTest {

    @Test
    void rejectsDefaultJwtSecretInProd() {
        LostMiracleProperties props = new LostMiracleProperties();
        props.getJwt().setSecret("change-me-to-a-long-random-secret-key-in-production");
        props.getGm().setBootstrapSuperPassword("real-password");

        MockEnvironment env = new MockEnvironment();
        env.setActiveProfiles("prod");

        ProductionSafetyCheck check = new ProductionSafetyCheck(props, env);
        assertThrows(IllegalStateException.class, check::checkProductionSafety);
    }

    @Test
    void rejectsDefaultGmPasswordInProd() {
        LostMiracleProperties props = new LostMiracleProperties();
        props.getJwt().setSecret("a-real-long-random-secret-key-12345678");
        props.getGm().setBootstrapSuperPassword("gm-admin-change-me");

        MockEnvironment env = new MockEnvironment();
        env.setActiveProfiles("prod");

        ProductionSafetyCheck check = new ProductionSafetyCheck(props, env);
        assertThrows(IllegalStateException.class, check::checkProductionSafety);
    }

    @Test
    void passesWithCustomValuesInProd() {
        LostMiracleProperties props = new LostMiracleProperties();
        props.getJwt().setSecret("a-real-long-random-secret-key-12345678");
        props.getGm().setBootstrapSuperPassword("real-password");

        MockEnvironment env = new MockEnvironment();
        env.setActiveProfiles("prod");

        ProductionSafetyCheck check = new ProductionSafetyCheck(props, env);
        assertDoesNotThrow(check::checkProductionSafety);
    }

    @Test
    void passesWithDefaultsWhenNotProd() {
        LostMiracleProperties props = new LostMiracleProperties();
        // defaults — no profile set
        MockEnvironment env = new MockEnvironment();

        ProductionSafetyCheck check = new ProductionSafetyCheck(props, env);
        assertDoesNotThrow(check::checkProductionSafety);
    }
}
