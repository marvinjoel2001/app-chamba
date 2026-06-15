allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: File = rootProject.projectDir.parentFile.resolve("build")
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir: File = newBuildDir.resolve(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
    // Fix for older Flutter plugins that don't specify a namespace or use old compileSdk
    project.pluginManager.withPlugin("com.android.library") {
        val androidExt = project.extensions.findByName("android") as? com.android.build.gradle.LibraryExtension
        if (androidExt != null) {
            androidExt.compileSdk = 36
            if (androidExt.namespace == null) {
                val groupStr = project.group.toString()
                if (groupStr.isNotEmpty()) {
                    androidExt.namespace = groupStr
                }
            }
        }
    }
    val setCompileSdk = { ext: Any ->
        try {
            val method = ext.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
            method.invoke(ext, 36)
        } catch (e: Exception) {
            // Ignore
        }
    }
    if (project.state.executed) {
        project.extensions.findByName("android")?.let { setCompileSdk(it) }
    } else {
        project.afterEvaluate {
            project.extensions.findByName("android")?.let { setCompileSdk(it) }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
