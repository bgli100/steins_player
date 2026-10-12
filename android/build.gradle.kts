allprojects {
    repositories {
        google()
        mavenCentral()
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
// The release lint check writes a jar cache into
// build\<module>\intermediates\lint-cache, and the Gradle daemon keeps those
// jars open after the build: the next release build then fails with a
// FileSystemException while it tries to replace one of them. The Dart analyzer
// and the tests cover the project, so the check is off for every module.
// (Registered before `evaluationDependsOn(":app")` below: AGP locks the lint
// options as soon as a project has been evaluated.)
subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.api.dsl.LibraryExtension> {
            lint { checkReleaseBuilds = false }
        }
    }
    plugins.withId("com.android.application") {
        extensions.configure<com.android.build.api.dsl.ApplicationExtension> {
            lint { checkReleaseBuilds = false }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
