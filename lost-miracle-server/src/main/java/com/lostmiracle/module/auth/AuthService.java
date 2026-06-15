package com.lostmiracle.module.auth;

import com.lostmiracle.common.BusinessException;
import com.lostmiracle.common.ErrorCode;
import com.lostmiracle.module.auth.dto.AuthResponse;
import com.lostmiracle.module.auth.dto.LoginRequest;
import com.lostmiracle.module.auth.dto.RegisterRequest;
import com.lostmiracle.module.user.entity.UserEntity;
import com.lostmiracle.module.user.mapper.UserMapper;
import com.lostmiracle.security.JwtTokenProvider;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

    private final UserMapper userMapper;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider jwtTokenProvider;

    public AuthService(UserMapper userMapper, PasswordEncoder passwordEncoder, JwtTokenProvider jwtTokenProvider) {
        this.userMapper = userMapper;
        this.passwordEncoder = passwordEncoder;
        this.jwtTokenProvider = jwtTokenProvider;
    }

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        long count = userMapper.countByUsername(request.username());
        if (count > 0) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "username already exists");
        }

        UserEntity user = new UserEntity();
        user.setUsername(request.username());
        user.setPasswordHash(passwordEncoder.encode(request.password()));
        user.setStatus(1);
        userMapper.insert(user);
        return buildAuthResponse(user);
    }

    public AuthResponse login(LoginRequest request) {
        UserEntity user = userMapper.selectByUsername(request.username());
        if (user == null || user.getStatus() == null || user.getStatus() != 1) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED, "invalid username or password");
        }
        if (!passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED, "invalid username or password");
        }
        return buildAuthResponse(user);
    }

    private AuthResponse buildAuthResponse(UserEntity user) {
        String token = jwtTokenProvider.createToken(user.getId(), user.getUsername());
        return new AuthResponse(token, jwtTokenProvider.getExpirationSeconds(), user.getId());
    }
}
