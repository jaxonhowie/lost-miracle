package com.lostmiracle.module.admin.dto;

import jakarta.validation.constraints.NotBlank;

import java.util.Map;

public class AdminSendMailRequest {

    private Long characterId;

    @NotBlank
    private String title;

    @NotBlank
    private String body;

    private Map<String, Object> attachments;

    public Long getCharacterId() { return characterId; }
    public void setCharacterId(Long characterId) { this.characterId = characterId; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getBody() { return body; }
    public void setBody(String body) { this.body = body; }

    public Map<String, Object> getAttachments() { return attachments; }
    public void setAttachments(Map<String, Object> attachments) { this.attachments = attachments; }
}
