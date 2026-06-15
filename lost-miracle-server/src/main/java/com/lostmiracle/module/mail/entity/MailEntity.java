package com.lostmiracle.module.mail.entity;

import java.time.LocalDateTime;

public class MailEntity {

    private Long id;
    private Long characterId;
    private String title;
    private String body;
    private String attachments;
    private Integer claimed;
    private LocalDateTime createdAt;
    private LocalDateTime claimedAt;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Long getCharacterId() { return characterId; }
    public void setCharacterId(Long characterId) { this.characterId = characterId; }
    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }
    public String getBody() { return body; }
    public void setBody(String body) { this.body = body; }
    public String getAttachments() { return attachments; }
    public void setAttachments(String attachments) { this.attachments = attachments; }
    public Integer getClaimed() { return claimed; }
    public void setClaimed(Integer claimed) { this.claimed = claimed; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
    public LocalDateTime getClaimedAt() { return claimedAt; }
    public void setClaimedAt(LocalDateTime claimedAt) { this.claimedAt = claimedAt; }
}
