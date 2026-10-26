# ==========================================
# Multi-stage Dockerfile for Spring Boot Backend
# Stage 1: Build JAR with Maven & OpenJDK 17
# ==========================================
FROM maven:3.9.6-eclipse-temurin-17-alpine AS builder

WORKDIR /build

# Copy Maven POM and download dependencies for layer caching
COPY pom.xml ./
RUN mvn dependency:go-offline -B

# Copy application source code
COPY src ./src

# Package the Spring Boot executable JAR without running tests (tests run in CI phase)
RUN mvn clean package -DskipTests=true

# ==========================================
# Stage 2: Minimal Secure JRE Runtime
# ==========================================
FROM eclipse-temurin:17-jre-alpine AS runtime

# Security: Create dedicated non-root user and group
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy the built jar from builder stage
COPY --from=builder /build/target/dictionary-backend-1.0.0.jar ./app.jar

# Adjust file ownership
RUN chown -R appuser:appgroup /app

# Run as non-root user
USER appuser

# Expose Spring Boot HTTP port
EXPOSE 8080

# Container Healthcheck targeting Spring Boot custom health endpoint
HEALTHCHECK --interval=15s --timeout=5s --retries=3 --start-period=25s \
  CMD wget --spider -q http://127.0.0.1:8080/api/health || exit 1

ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "/app/app.jar"]
