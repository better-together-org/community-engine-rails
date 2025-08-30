Quick guide: enable a placeholder spec and run the screenshot job

- Open the generated spec under `spec/docs_screenshots/` and find the example you want to enable (it will include `skip: 'placeholder - update visit'`).
- Replace or remove the `skip: 'placeholder - update visit'` metadata on the `it` example.
- Update the `visit '/' # TODO: ...` line to point to a real path the app exposes (for example `visit '/some_path'`).
- Run the screenshot job using the repository wrapper which sets the required env var and runs the specs:

```bash
./bin/docs_screenshots
```

Notes and safety
- The examples are skipped by default to avoid accidental browser runs during normal test execution. Only enable them when ready.
- The job will write images to `docs/screenshots/desktop` and `docs/screenshots/mobile` and JSON sidecars next to each image containing metadata.
- If you need to run inside the project container or with services available, run the wrapper from the project root inside the container environment.
