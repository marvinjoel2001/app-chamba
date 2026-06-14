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
            if (androidExt.namespace == null) {
                val groupStr = project.group.toString()
                if (groupStr.isNotEmpty()) {
                    androidExt.namespace = groupStr
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
