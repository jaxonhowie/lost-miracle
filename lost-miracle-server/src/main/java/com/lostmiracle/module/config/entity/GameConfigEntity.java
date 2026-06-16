package com.lostmiracle.module.config.entity;

import java.time.LocalDateTime;

public class GameConfigEntity {

    private String configKey;
    private String draftJson;
    private String publishedJson;
    private String description;
    private LocalDateTime updatedAt;

    public String getConfigKey() { return configKey; }
    public void setConfigKey(String configKey) { this.configKey = configKey; }
    public String getDraftJson() { return draftJson; }
    public void setDraftJson(String draftJson) { this.draftJson = draftJson; }
    public String getPublishedJson() { return publishedJson; }
    public void setPublishedJson(String publishedJson) { this.publishedJson = publishedJson; }
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }
}
