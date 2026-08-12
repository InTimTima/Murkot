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
subprojects {
    project.evaluationDependsOn(":app")
}

// Plugins like file_picker ship with compileSdk 34 while
// flutter_plugin_android_lifecycle now requires 36+.
fun Project.forceCompileSdk36() {
    val androidExt = extensions.findByName("android") ?: return
    for (methodName in listOf("setCompileSdk", "setCompileSdkVersion")) {
        val setter = androidExt.javaClass.methods.firstOrNull {
            it.name == methodName && it.parameterCount == 1
        } ?: continue
        val param = setter.parameterTypes[0]
        try {
            when {
                param == Int::class.javaPrimitiveType || param == Int::class.javaObjectType ->
                    setter.invoke(androidExt, 36)
                param == String::class.java ->
                    setter.invoke(androidExt, "android-36")
                else -> continue
            }
            return
        } catch (_: Exception) {
            // try next setter
        }
    }
}

subprojects {
    // evaluationDependsOn(":app") above can evaluate plugins early,
    // so handle both "not yet evaluated" and "already evaluated".
    if (state.executed) {
        forceCompileSdk36()
    } else {
        afterEvaluate { forceCompileSdk36() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
