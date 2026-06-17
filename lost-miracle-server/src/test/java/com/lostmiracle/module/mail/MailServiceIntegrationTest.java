package com.lostmiracle.module.mail;

import com.lostmiracle.module.mail.dto.ClaimMailRequest;
import com.lostmiracle.module.mail.dto.ClaimMailResponse;
import com.lostmiracle.module.save.entity.CharacterSaveEntity;
import com.lostmiracle.module.save.mapper.CharacterSaveMapper;
import com.lostmiracle.support.IntegrationTestBase;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertTrue;

class MailServiceIntegrationTest extends IntegrationTestBase {

    @Autowired
    private MailService mailService;

    @Autowired
    private CharacterSaveMapper characterSaveMapper;

    @Test
    void claim_shouldApplyAttachmentsAndBumpVersion() {
        TestUser user = createUser("mail_claim");
        long mailId = insertMail(user.characterId(), "{\"gold\":100,\"enhance_stone\":2}");

        ClaimMailResponse response = mailService.claim(
                user.userId(),
                user.characterId(),
                mailId,
                new ClaimMailRequest(user.saveVersion())
        );

        assertTrue(response.saveVersion() > user.saveVersion());

        CharacterSaveEntity updated = characterSaveMapper.selectById(user.characterId());
        assertTrue(updated.getSaveVersion() == response.saveVersion());

        @SuppressWarnings("unchecked")
        Map<String, Object> player = (Map<String, Object>) response.save().get("player");
        assertTrue(((Number) player.get("gold")).intValue() >= 100);
    }
}
