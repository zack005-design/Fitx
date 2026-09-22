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
subprojects {
    if (project.name != "app") {
        project.plugins.withId("com.android.library") {
            try {
                val android = project.extensions.findByName("android")
                val getSourceSets = android?.javaClass?.getMethod("getSourceSets")
                val sourceSets = getSourceSets?.invoke(android) as? org.gradle.api.NamedDomainObjectContainer<*>
                val main = sourceSets?.findByName("main")
                if (main != null) {
                    val getJava = main.javaClass.getMethod("getJava")
                    val java = getJava.invoke(main)
                    val srcDir = java?.javaClass?.getMethod("srcDir", Any::class.java)
                    srcDir?.invoke(java, "src/main/kotlin")
                }
            } catch (_: Exception) {}
        }
        afterEvaluate {
            val android = project.extensions.findByName("android")
            if (android != null) {
                for (method in android.javaClass.methods) {
                    if (method.name in listOf("setCompileSdk", "setCompileSdkVersion", "compileSdkVersion") &&
                        method.parameterTypes.size == 1 &&
                        (method.parameterTypes[0] == Int::class.javaPrimitiveType || method.parameterTypes[0] == java.lang.Integer::class.java)
                    ) {
                        try {
                            method.invoke(android, 37)
                        } catch (_: Exception) {}
                    }
                }

                try {
                    val getSourceSets = android.javaClass.getMethod("getSourceSets")
                    val sourceSets = getSourceSets.invoke(android) as? org.gradle.api.NamedDomainObjectContainer<*>
                    val main = sourceSets?.findByName("main")
                    if (main != null) {
                        val getJava = main.javaClass.getMethod("getJava")
                        val java = getJava.invoke(main)
                        val srcDir = java?.javaClass?.getMethod("srcDir", Any::class.java)
                        srcDir?.invoke(java, "src/main/kotlin")
                    }
                } catch (_: Exception) {}
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
