import org.gradle.api.file.Directory
import org.gradle.api.tasks.Delete

allprojects {
    repositories { google(); mavenCentral(); maven(url = uri("https://storage.googleapis.com/download.flutter.io")) }
}
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)
subprojects {
    val subBuild: Directory = newBuildDir.dir(project.name)
    layout.buildDirectory.value(subBuild)
}
tasks.register<Delete>("clean") { delete(rootProject.layout.buildDirectory) }
