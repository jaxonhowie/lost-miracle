package com.lostmiracle.support;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.lostmiracle.module.auth.AuthService;
import com.lostmiracle.module.auth.dto.AuthResponse;
import com.lostmiracle.module.auth.dto.RegisterRequest;
import com.lostmiracle.module.character.CharacterService;
import com.lostmiracle.module.character.dto.CharacterSummaryResponse;
import com.lostmiracle.module.character.dto.CreateCharacterRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;

import java.util.Map;
import java.util.UUID;

@SpringBootTest
@ActiveProfiles("integration")
@Import(IntegrationTestConfig.class)
public abstract class IntegrationTestBase {

    @DynamicPropertySource
    static void integrationDataSource(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", () ->
                "jdbc:h2:mem:lm_" + UUID.randomUUID().toString().replace("-", "")
                        + ";MODE=MySQL;DB_CLOSE_DELAY=-1;NON_KEYWORDS=USER,CHARACTER");
    }

    @Autowired
    protected AuthService authService;

    @Autowired
    protected CharacterService characterService;

    @Autowired
    protected ObjectMapper objectMapper;

    @Autowired
    protected JdbcTemplate jdbcTemplate;

    protected TestUser createUser(String suffix) {
        String username = "user_" + suffix;
        AuthResponse auth = authService.register(new RegisterRequest(username, "password123"));
        CharacterSummaryResponse character = characterService.createCharacter(
                auth.userId(),
                new CreateCharacterRequest("测试角色")
        );
        return new TestUser(auth.userId(), auth.accessToken(), character.id(), character.saveVersion());
    }

    protected long insertMail(long characterId, String attachmentsJson) {
        jdbcTemplate.update(
                """
                        INSERT INTO mail (character_id, title, body, attachments, claimed, created_at)
                        VALUES (?, ?, ?, ?, 0, CURRENT_TIMESTAMP)
                        """,
                characterId,
                "测试邮件",
                "奖励附件",
                attachmentsJson
        );
        Long id = jdbcTemplate.queryForObject("SELECT MAX(id) FROM mail WHERE character_id = ?", Long.class, characterId);
        return id == null ? 0L : id;
    }

    protected Map<String, Object> readSaveMap(String saveJson) throws Exception {
        return objectMapper.readValue(saveJson, new TypeReference<>() {
        });
    }

    protected record TestUser(long userId, String token, long characterId, long saveVersion) {
    }
}
