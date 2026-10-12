package com.sahayak.backend.modules.user;

/**
 * SAHAYAK Platform Application Roles.
 * Maps consistently to Spring Security authorities prefixed with "ROLE_".
 * Authorization expressions use hasRole("USER"), hasRole("PARENT"), hasRole("ADMIN").
 */
public enum Role {
    USER,
    PARENT,
    ADMIN;

    public String getAuthority() {
        return "ROLE_" + this.name();
    }
}
