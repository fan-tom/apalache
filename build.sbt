import Dependencies._

///////////////////////////
// Project-wide settings //
///////////////////////////

name := "apalache"

// See https://www.scala-sbt.org/1.x/docs/Multi-Project.html#Build-wide+settings
ThisBuild / organizationName := "Informal Systems Inc."
ThisBuild / organizationHomepage := Some(url("https://informal.systems"))
ThisBuild / licenses += "Apache 2.0" -> url("https://www.apache.org/licenses/LICENSE-2.0")

// We store the version in a bare file to make accessing and updating the version trivial
ThisBuild / versionFile := (ThisBuild / baseDirectory).value / "VERSION"
ThisBuild / version := scala.io.Source.fromFile(versionFile.value).mkString.trim

ThisBuild / organization := "at.forsyte"
ThisBuild / scalaVersion := "2.12.15"

// https://oss.sonatype.org/content/repositories/snapshots/
ThisBuild / resolvers += Resolver.sonatypeRepo("snapshots")

// Shared dependencies accross all sub projects
ThisBuild / libraryDependencies ++= Seq(
    Deps.guice,
    Deps.logbackClassic,
    Deps.logbackCore,
    Deps.slf4j,
    Deps.tla2tools,
    Deps.z3,
    Deps.logging,
    Deps.scalaParserCombinators,
    Deps.scalaz,
    TestDeps.junit,
    TestDeps.easymock,
    TestDeps.scalatest,
    TestDeps.scalacheck,
)

// Only check/fix against (tracked) files that have changed relative to the trunk
ThisBuild / scalafmtFilter := "diff-ref=origin/unstable"

///////////////////////////////
// Test configuration //
///////////////////////////////

// NOTE: Include these settings in any projects that require Apalache's TLA+ modules
lazy val tlaModuleTestSettings = Seq(
    // we have to tell SANY the location of Apalache modules for the tests
    Test / fork := true, // Forking is required for the system options to take effect in the tests
    Test / javaOptions += s"""-DTLA-Library=${(ThisBuild / baseDirectory).value / "src" / "tla"}""",
)

lazy val testSettings = Seq(
    Test / testOptions += Tests.Argument(TestFrameworks.ScalaTest, "-oDT"),
)

/////////////////////////////
// Sub-project definitions //
/////////////////////////////

lazy val tlair = (project in file("tlair"))
  .settings(
      testSettings,
      libraryDependencies ++= Seq(
          Deps.ujson,
          Deps.kiama,
      ),
  )

lazy val infra = (project in file("mod-infra"))
  .dependsOn(tlair)
  .settings(
      testSettings,
  )

lazy val tla_io = (project in file("tla-io"))
  .dependsOn(tlair, infra)
  .settings(
      testSettings,
      tlaModuleTestSettings,
      libraryDependencies ++= Seq(
          Deps.commonsIo,
          Deps.pureConfig,
      ),
  )

lazy val tla_types = (project in file("tla-types"))
  .dependsOn(tlair, infra, tla_io)
  .settings(
      testSettings,
      tlaModuleTestSettings,
      libraryDependencies += Deps.commonsIo,
  )

lazy val tla_pp = (project in file("tla-pp"))
  .dependsOn(
      tlair,
      // property based tests depend on IR generators defined in the tlair tests
      // See https://www.scala-sbt.org/1.x/docs/Multi-Project.html#Per-configuration+classpath+dependencies
      tlair % "test->test",
      infra,
      tla_io,
      tla_types,
  )
  .settings(
      testSettings,
      tlaModuleTestSettings,
      libraryDependencies += Deps.commonsIo,
  )

lazy val tla_assignments = (project in file("tla-assignments"))
  .dependsOn(tlair, infra, tla_io, tla_pp, tla_types)
  .settings(
      testSettings,
      libraryDependencies += Deps.commonsIo,
  )

lazy val tla_bmcmt = (project in file("tla-bmcmt"))
  .dependsOn(tlair, infra, tla_io, tla_pp, tla_assignments)
  .settings(
      testSettings,
  )

lazy val tool = (project in file("mod-tool"))
  .dependsOn(tlair, tla_io, tla_assignments, tla_bmcmt)
  .settings(
      testSettings,
      libraryDependencies ++= Seq(
          Deps.commonsConfiguration2,
          Deps.commonsBeanutils,
          Deps.clistCore,
          Deps.clistMacros,
      ),
  )

lazy val distribution = (project in file("mod-distribution"))
  .dependsOn(tlair, tla_io, tla_assignments, tla_bmcmt, tool)
  .settings(
      testSettings,
  )

///////////////
// Packaging //
///////////////

// Define the main entrypoint and uber jar package
lazy val root = (project in file("."))
  .dependsOn(distribution)
  .aggregate(
      // propagate commands to these sub-projects
      tlair,
      infra,
      tla_io,
      tla_types,
      tla_pp,
      tla_assignments,
      tla_bmcmt,
      tool,
      distribution,
  )
  .settings(
      testSettings,
      // Package definition
      Compile / packageBin / mappings ++= Seq(
          // Include theese assets in the compiled package at the specified locations
          ((ThisBuild / baseDirectory).value / "README.md" -> "README.md"),
          ((ThisBuild / baseDirectory).value / "LICENSE" -> "LICENSE"),
      ),
      assembly / assemblyJarName := s"apalache-pkg-${version.value}-full.jar",
      assembly / mainClass := Some("at.forsyte.apalache.tla.Tool"),
      assembly / assembledMappings += {
        val src_dir = (ThisBuild / baseDirectory).value / "src" / "tla"
        // See https://github.com/sbt/sbt-assembly/issues/227#issuecomment-283504401
        sbtassembly.MappingSet(
            None,
            Vector(
                (src_dir / "Apalache.tla") -> "tla2sany/StandardModules/Apalache.tla",
                (src_dir / "Variants.tla") -> "tla2sany/StandardModules/Variants.tla",
            ),
        )
      },
  )

// Specify and build the docker file
enablePlugins(DockerPlugin)

docker / imageNames := {
  val img: String => ImageName = s =>
    ImageName(
        namespace = Some("ghcr.io/informalsystems"),
        repository = name.value,
        tag = Some(s),
    )
  Seq(
      img(version.value),
      img("latest"),
  )
}

docker / dockerfile := {
  val rootDir = (ThisBuild / baseDirectory).value
  // Docker Working Dir
  val dwd = "/opt/apalache"

  val fatJar = assembly.value
  val jarTarget = s"${dwd}/target/scala-2.12/${fatJar.name}"

  val runners = rootDir / "bin"
  val runnersTarget = s"${dwd}/bin"

  // val modules = rootDir / "src" / "tla"
  // val modulesTarget = s"${dwd}/src/tla"

  val license = rootDir / "LICENSE"
  val readme = rootDir / "README.md"

  new Dockerfile {
    from("eclipse-temurin:16")

    workDir(dwd)

    add(fatJar, jarTarget)
    add(runners, runnersTarget)
    add(license, s"${dwd}/${license.name}")
    add(readme, s"${dwd}/${readme.name}")
    // add(modules, modulesTarget)

    // TLA parser requires all specification files to be in the same directory
    // We assume the user bind-mounted the spec dir into /var/apalache
    // but, in case the directory was not bind-mounted, we create one
    run("mkdir", "/var/apalache")

    // We need sudo to run apalache using the user (created in the entrypoint script)
    run("apt", "update")
    run("apt", "install", "sudo")

    entryPoint("/opt/apalache/bin/run-in-docker-container")
  }
}

//////////////
// appendix //
//////////////

// For some reason `scalafmtFilter` doesn't register as being used, tho it is
// so this quiets the erroneous linting.
Global / excludeLintKeys += scalafmtFilter

lazy val versionFile = settingKey[File]("Location of the file tracking the project version")

// These tasks are used in our bespoke release pipeline
// TODO(shon): Once we've changed our packaging to conform to more standard SBT structures and practices,
// we should consider moving to a release pipeline based around sbt-release.
// See https://github.com/informalsystems/apalache/issues/1248

lazy val printVersion = taskKey[Unit]("Print the current version")
printVersion := {
  println((ThisBuild / version).value)
}

lazy val removeVersionSnapshot = taskKey[Unit]("Remove version snapshot from the version file")
removeVersionSnapshot := {
  val releaseVersion = (ThisBuild / version).value.stripSuffix("-SNAPSHOT")
  IO.writeLines((ThisBuild / versionFile).value, Seq(releaseVersion))
}

lazy val setVersion = inputKey[Unit]("Set the version recorded in the version file")
setVersion := {
  val version: String = complete.Parsers.spaceDelimited("<args>").parsed(0)
  IO.writeLines((ThisBuild / versionFile).value, Seq(version))
}

lazy val incrVersion = taskKey[String]("Increment to the next patch snapshot version")
incrVersion := {
  val fullVersion = (ThisBuild / version).value
  val currentVersion =
    try {
      fullVersion.split("-")(0)
    } catch {
      case _: ArrayIndexOutOfBoundsException =>
        throw new RuntimeException(s"Invalid version: ${fullVersion}")
    }
  val nextVersion = currentVersion.split("\\.") match {
    case Array(maj, min, patch) => {
      val nextPatch = ((patch.toInt) + 1).toString
      s"${maj}.${min}.${nextPatch}-SNAPSHOT"
    }
    case arr =>
      throw new RuntimeException(s"Invalid version: ${fullVersion}")
  }
  IO.writeLines((ThisBuild / versionFile).value, Seq(nextVersion))
  nextVersion
}
