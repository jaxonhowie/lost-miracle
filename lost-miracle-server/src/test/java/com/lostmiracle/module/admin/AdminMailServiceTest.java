package com.lostmiracle.module.admin;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.lostmiracle.module.admin.dto.AdminSendMailRequest;
import com.lostmiracle.module.character.mapper.CharacterMapper;
import com.lostmiracle.module.mail.entity.MailEntity;
import com.lostmiracle.module.mail.mapper.MailMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class AdminMailServiceTest {

    private MailMapper mailMapper;
    private CharacterMapper characterMapper;
    private AdminMailService adminMailService;

    @BeforeEach
    void setUp() {
        mailMapper = mock(MailMapper.class);
        characterMapper = mock(CharacterMapper.class);
        adminMailService = new AdminMailService(mailMapper, characterMapper, new ObjectMapper());
    }

    @Test
    void sendMail_toSingleCharacter() {
        AdminSendMailRequest request = new AdminSendMailRequest();
        request.setCharacterId(42L);
        request.setTitle("测试邮件");
        request.setBody("内容");
        request.setAttachments(Map.of("gold", 100));

        int count = adminMailService.sendMail(request);

        assertEquals(1, count);
        ArgumentCaptor<MailEntity> captor = ArgumentCaptor.forClass(MailEntity.class);
        verify(mailMapper, times(1)).insert(captor.capture());
        MailEntity mail = captor.getValue();
        assertEquals(42L, mail.getCharacterId());
        assertEquals("测试邮件", mail.getTitle());
        assertTrue(mail.getAttachments().contains("gold"));
    }

    @Test
    void sendMail_broadcast() {
        when(characterMapper.selectAllIds()).thenReturn(List.of(1L, 2L, 3L));

        AdminSendMailRequest request = new AdminSendMailRequest();
        request.setTitle("全服邮件");
        request.setBody("奖励");
        request.setAttachments(Map.of("enhance_stone", 10));

        int count = adminMailService.sendMail(request);

        assertEquals(3, count);
        verify(mailMapper, times(3)).insert(any(MailEntity.class));
    }

    @Test
    void sendMail_broadcastEmptyServer() {
        when(characterMapper.selectAllIds()).thenReturn(List.of());

        AdminSendMailRequest request = new AdminSendMailRequest();
        request.setTitle("空服邮件");
        request.setBody("内容");

        int count = adminMailService.sendMail(request);

        assertEquals(0, count);
        verify(mailMapper, never()).insert(any());
    }

    @Test
    void sendMail_noAttachments() {
        AdminSendMailRequest request = new AdminSendMailRequest();
        request.setCharacterId(1L);
        request.setTitle("无附件");
        request.setBody("纯文本");

        adminMailService.sendMail(request);

        ArgumentCaptor<MailEntity> captor = ArgumentCaptor.forClass(MailEntity.class);
        verify(mailMapper).insert(captor.capture());
        assertNull(captor.getValue().getAttachments());
    }

    @Test
    void sendMail_emptyAttachments() {
        AdminSendMailRequest request = new AdminSendMailRequest();
        request.setCharacterId(1L);
        request.setTitle("空附件");
        request.setBody("内容");
        request.setAttachments(Map.of());

        adminMailService.sendMail(request);

        ArgumentCaptor<MailEntity> captor = ArgumentCaptor.forClass(MailEntity.class);
        verify(mailMapper).insert(captor.capture());
        assertNull(captor.getValue().getAttachments());
    }
}
