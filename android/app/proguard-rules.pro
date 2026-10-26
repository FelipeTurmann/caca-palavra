# Room creates WorkManager's database through reflection during Android startup.
# With the bundled Room 2.2.5 rules, R8 removes this constructor in release builds,
# causing InitializationProvider to crash before Flutter can show the first screen.
-keep class androidx.work.impl.WorkDatabase_Impl {
    public <init>();
}
