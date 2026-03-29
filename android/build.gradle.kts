allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Update buildscript block at the beginning of the file
buildscript {
    val kotlinVersion = "1.9.0"  // Define as a regular variable
    
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:7.3.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
        classpath("com.google.gms:google-services:4.3.15")
    }
}

// SIMPLIFIED: Use standard build directory configuration
rootProject.buildDir = File("../build")

subprojects {
    project.buildDir = File("${rootProject.buildDir}/${project.name}")
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}