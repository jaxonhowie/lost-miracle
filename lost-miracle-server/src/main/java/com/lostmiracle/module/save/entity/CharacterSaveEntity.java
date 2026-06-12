package com.lostmiracle.module.save.entity;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;

import java.time.LocalDateTime;

@TableName("character_save")
public class CharacterSaveEntity {

    @TableId
    private Long characterId;
    private Long saveVersion;
    private String saveJson;
    private String checksum;
    private Long clientUpdatedAt;
    private LocalDateTime serverUpdatedAt;

    public Long getCharacterId() {
        return characterId;
    }

    public void setCharacterId(Long characterId) {
        this.characterId = characterId;
    }

    public Long getSaveVersion() {
        return saveVersion;
    }

    public void setSaveVersion(Long saveVersion) {
        this.saveVersion = saveVersion;
    }

    public String getSaveJson() {
        return saveJson;
    }

    public void setSaveJson(String saveJson) {
        this.saveJson = saveJson;
    }

    public String getChecksum() {
        return checksum;
    }

    public void setChecksum(String checksum) {
        this.checksum = checksum;
    }

    public Long getClientUpdatedAt() {
        return clientUpdatedAt;
    }

    public void setClientUpdatedAt(Long clientUpdatedAt) {
        this.clientUpdatedAt = clientUpdatedAt;
    }

    public LocalDateTime getServerUpdatedAt() {
        return serverUpdatedAt;
    }

    public void setServerUpdatedAt(LocalDateTime serverUpdatedAt) {
        this.serverUpdatedAt = serverUpdatedAt;
    }
}
