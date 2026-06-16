package com.lostmiracle.module.admin.entity;

import java.time.LocalDateTime;

public class GmAuditLogEntity {

    private Long id;
    private Long gmAccountId;
    private String action;
    private String targetType;
    private String targetId;
    private String detailJson;
    private String ip;
    private LocalDateTime createdAt;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Long getGmAccountId() { return gmAccountId; }
    public void setGmAccountId(Long gmAccountId) { this.gmAccountId = gmAccountId; }
    public String getAction() { return action; }
    public void setAction(String action) { this.action = action; }
    public String getTargetType() { return targetType; }
    public void setTargetType(String targetType) { this.targetType = targetType; }
    public String getTargetId() { return targetId; }
    public void setTargetId(String targetId) { this.targetId = targetId; }
    public String getDetailJson() { return detailJson; }
    public void setDetailJson(String detailJson) { this.detailJson = detailJson; }
    public String getIp() { return ip; }
    public void setIp(String ip) { this.ip = ip; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}
