package com.lostmiracle.module.system.entity;

import java.time.LocalDateTime;

public class SystemSettingEntity {

    private String key;
    private String value;
    private LocalDateTime updatedAt;

    public String getKey() { return key; }
    public void setKey(String key) { this.key = key; }

    public String getValue() { return value; }
    public void setValue(String value) { this.value = value; }

    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }
}
