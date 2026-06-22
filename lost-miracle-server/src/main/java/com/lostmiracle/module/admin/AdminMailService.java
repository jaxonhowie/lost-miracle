package com.lostmiracle.module.admin;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.lostmiracle.common.BusinessException;
import com.lostmiracle.common.ErrorCode;
import com.lostmiracle.module.admin.dto.AdminSendMailRequest;
import com.lostmiracle.module.character.mapper.CharacterMapper;
import com.lostmiracle.module.mail.entity.MailEntity;
import com.lostmiracle.module.mail.mapper.MailMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;

@Service
public class AdminMailService {

    private static final Logger log = LoggerFactory.getLogger(AdminMailService.class);

    private final MailMapper mailMapper;
    private final CharacterMapper characterMapper;
    private final ObjectMapper objectMapper;

    public AdminMailService(MailMapper mailMapper, CharacterMapper characterMapper, ObjectMapper objectMapper) {
        this.mailMapper = mailMapper;
        this.characterMapper = characterMapper;
        this.objectMapper = objectMapper;
    }

    public int sendMail(AdminSendMailRequest request) {
        String attachmentsJson = serializeAttachments(request.getAttachments());

        if (request.getCharacterId() != null) {
            sendToCharacter(request.getCharacterId(), request.getTitle(), request.getBody(), attachmentsJson);
            return 1;
        }

        List<Long> allIds = characterMapper.selectAllIds();
        for (long characterId : allIds) {
            sendToCharacter(characterId, request.getTitle(), request.getBody(), attachmentsJson);
        }
        log.info("broadcast mail to {} characters: title={}", allIds.size(), request.getTitle());
        return allIds.size();
    }

    private void sendToCharacter(long characterId, String title, String body, String attachmentsJson) {
        MailEntity mail = new MailEntity();
        mail.setCharacterId(characterId);
        mail.setTitle(title);
        mail.setBody(body);
        mail.setAttachments(attachmentsJson);
        mailMapper.insert(mail);
    }

    private String serializeAttachments(Map<String, Object> attachments) {
        if (attachments == null || attachments.isEmpty()) {
            return null;
        }
        try {
            return objectMapper.writeValueAsString(attachments);
        } catch (JsonProcessingException e) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "invalid attachments JSON");
        }
    }
}
