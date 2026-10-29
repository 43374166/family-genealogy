allprojects {
    repositories {
        google()
        mavenCentral()
        // The Tsinghua Flutter mirror does not currently host the engine AARs
        // for this Flutter version. Prefer the Flutter China mirror, then the
        // official read-only repository, without changing the SDK mirror for
        // other Flutter artifacts.
        maven {
            url = uri("https://storage.flutter-io.cn/download.flutter.io")
            content { includeGroup("io.flutter") }
        }
        maven {
            url = uri("https://storage.googleapis.com/download.flutter.io")
            content { includeGroup("io.flutter") }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
