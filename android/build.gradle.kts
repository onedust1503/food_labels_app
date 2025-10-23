buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        // ✅ 使用穩定的 AGP 8.7.2（與 Gradle 8.11.1 兼容）
        classpath("com.android.tools.build:gradle:8.7.2")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.25")
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ✅ 修正 build 目錄配置，讓 Flutter 能找到 APK
rootProject.layout.buildDirectory.set(file("${rootProject.projectDir}/../build"))

subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            project.layout.buildDirectory.set(
                file("${rootProject.layout.buildDirectory.get().asFile}/${project.name}")
            )
        }
    }
    
    project.configurations.all {
        resolutionStrategy {
            force("com.google.code.findbugs:jsr305:3.0.2")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}