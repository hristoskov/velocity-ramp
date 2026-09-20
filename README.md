# Velocity Ramp Controller

[![CI](https://github.com/hristoskov/velocity-ramp/actions/workflows/ci.yml/badge.svg)](https://github.com/hristoskov/velocity-ramp/actions/workflows/ci.yml)

A minimal [CppModel](https://www.cppmodel.com) simulation, written to accompany an
article introducing CppModel. It exercises a small C controller that ramps an actuator's
velocity toward a series of setpoints, using separate acceleration and braking settle
windows, and checks that it always settles in time.

The controller under test lives entirely in [velocity_ramp_controller.c](velocity_ramp_controller.c):

- `VELOCITY_SCHEDULE` drives the target velocity through four setpoints (`50 -> 150 -> 30 -> 0`)
  at fixed times.
- `RampStep` moves the actual velocity toward the target by at most `MaxAcceleration` per
  cycle.
- Each cycle reports `CppModel.StepResult` = 1 as long as the ramp is still within its
  settle window (`AccelerationWindowTimeMs` while speeding up, `BrakingWindowTimeMs` while
  braking) or has already reached the target within `VELOCITY_EPSILON`.

CppModel drives the simulation cycle-by-cycle, feeding in `DesiredVelocity`/parameters and
recording `ActualVelocity` and `CppModel.StepResult` — see
[CModel.h](dependencies/include/cppmodel/CModel.h) for the full C API surface used by
`CMODEL_CYCLIC()`/`CMODEL_SIMULATE()`.

## Prerequisites

- CMake >= 3.12
- A C and C++17 compiler (GCC, Clang, or MSVC)
- OpenSSL and zlib development libraries (needed by the CppModel client libraries)
- A free [CppModel](https://www.cppmodel.com) account — running the binary directly
  prompts you to log in through your browser; running non-interactively (e.g. via `ctest`)
  needs credentials in `.env` instead (see [Credentials](#2-credentials) below)

## 1. Fetch the CppModel dependencies

The CppModel headers and static libraries aren't vendored in this repo — pull them with
the platform script for your OS. Both scripts write into `dependencies/` (already
git-ignored) and auto-detect your OS/architecture and, on Linux, your compiler:

```sh
# Linux / macOS
./scripts/update-cppmodel.sh

# Windows (PowerShell)
.\scripts\update-cppmodel.ps1
```

Run this again whenever you want to update to the latest CppModel release — it replaces
the contents of `dependencies/` each time.

## 2. Credentials

Running the binary directly is interactive: it opens your default browser to the CppModel
login page the first time (and whenever your session has expired), so sign up for a free
account at [www.cppmodel.com](https://www.cppmodel.com) if you don't have one yet, then log
in there to let the run proceed.

Running non-interactively — e.g. via `ctest`, or in CI — has no browser to log in with, so
it needs credentials supplied up front instead. Copy the example env file and fill in your
account:

```sh
cp .env.example .env
```

```
CPPMODEL_USERNAME=you@example.com
CPPMODEL_PASSWORD=your-password
```

`.env` is git-ignored — never commit it.

## 3. Build

```sh
cmake -S . -B build
cmake --build build
```

## 4. Run

```sh
./build/velocity_ramp_controller
```

Exit code `0` means every cycle's `CppModel.StepResult` was `1`, i.e. the ramp always
settled within its window. A non-zero exit means at least one cycle failed. Either way,
the run prints a `UI: https://workspace.cppmodel.com/simulations/...` link — open it to
inspect the full per-cycle signal trace.

### Run via CTest

The simulation is also registered as a CMake/CTest test (see
[CMakeLists.txt](CMakeLists.txt)), so it can run alongside any other tests in the project.
`ctest` runs non-interactively, so source `.env` first (see [Credentials](#2-credentials)):

```sh
set -a && source .env && set +a
cd build && ctest --output-on-failure
```

## Project layout

| Path                            | Description                                              |
| -------------------------------- | ---------------------------------------------------------- |
| `velocity_ramp_controller.c`     | The controller under test and its CppModel simulation      |
| `CMakeLists.txt`                 | Build definition; registers the simulation with CTest      |
| `scripts/update-cppmodel.sh/.ps1`| Downloads the CppModel headers/libs into `dependencies/`   |
| `.github/workflows/ci.yml`       | Builds and tests on Linux, macOS, and Windows               |
| `.env.example`                   | Template for the credentials needed by non-interactive runs |
| `dependencies/`                  | CppModel headers, static libs, and third-party licenses (fetched, git-ignored) |

## Continuous integration

[.github/workflows/ci.yml](.github/workflows/ci.yml) builds and `ctest`s the simulation on
every push/PR to `main`, using the latest compiler each platform supports:

| OS      | Compiler              |
| ------- | ---------------------- |
| Linux   | GCC 16                 |
| macOS   | AppleClang (Xcode CLT) |
| Windows | MSVC                   |

Each job runs `scripts/update-cppmodel.sh`/`.ps1` for that platform, then builds and runs
`ctest` exactly as described above. Since `ctest` runs non-interactively, the workflow needs
`CPPMODEL_USERNAME` and `CPPMODEL_PASSWORD` set as [repository
secrets](../../settings/secrets/actions) (Settings → Secrets and variables → Actions) —
without them, every job's test step fails at login.

## Third-party licenses

The CppModel distribution pulled by `scripts/update-cppmodel.*` bundles a few third-party
libraries; their licenses are included at `dependencies/licenses/` after fetching
(cpp-httplib, IXWebSocket, jwt-cpp, nlohmann/json, OpenSSL, picojson).

## License

The code in this repository (everything outside `dependencies/`) is available under the
[MIT License](LICENSE).
