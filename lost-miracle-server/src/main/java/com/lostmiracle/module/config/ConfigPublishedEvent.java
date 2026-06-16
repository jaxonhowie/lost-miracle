package com.lostmiracle.module.config;

import org.springframework.context.ApplicationEvent;

public class ConfigPublishedEvent extends ApplicationEvent {

    private final long version;

    public ConfigPublishedEvent(Object source, long version) {
        super(source);
        this.version = version;
    }

    public long getVersion() {
        return version;
    }
}
