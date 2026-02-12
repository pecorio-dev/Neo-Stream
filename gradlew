#!/bin/sh
# Gradle wrapper script
APP_NAME="Gradle"
CLASSPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )/gradle/wrapper/gradle-wrapper.jar"

# Determine the Java command to use
if [ -n "$JAVA_HOME" ] ; then
    JAVACMD="$JAVA_HOME/bin/java"
else
    JAVACMD="java"
fi

exec "$JAVACMD" $JAVA_OPTS -classpath "$CLASSPATH" org.gradle.wrapper.GradleWrapperMain "$@"
