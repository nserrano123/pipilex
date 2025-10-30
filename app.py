import json
import asyncio
from pathlib import Path

from pipelex import pretty_print
from pipelex.pipelex import Pipelex
from pipelex.pipeline.execute import execute_pipeline

INPUTS_PATH = Path("results/inputs.json")
PIPE_CODE = "appointment_scheduling_workflow"
BUNDLE_PATHS = [str(Path("results/generated_pipeline_1st_iteration_01.plx").resolve())]
PLX_PATH = Path("results/generated_pipeline_1st_iteration_01.plx")


async def run_with_inputs(inputs_path: Path) -> str:
    if not inputs_path.exists():
        raise FileNotFoundError(f"Inputs file not found at: {inputs_path}")

    with inputs_path.open("r", encoding="utf-8") as f:
        inputs = json.load(f)

    required_keys = [
        "person_email",
        "person_phone",
        "google_calendar_credentials",
        "whatsapp_credentials",
    ]
    missing = [k for k in required_keys if k not in inputs]
    if missing:
        raise ValueError(
            "Missing required inputs in JSON: " + ", ".join(missing)
        )

    plx_content = PLX_PATH.read_text(encoding="utf-8")

    pipe_output = await execute_pipeline(
        # pipe_code optional when main_pipe is set in the PLX bundle
        plx_content=plx_content,
        inputs=inputs,
    )

    return pipe_output.main_stuff_as_str


if __name__ == "__main__":
    Pipelex.make()
    output_text = asyncio.run(run_with_inputs(INPUTS_PATH))
    pretty_print(output_text, title="Appointment Scheduling - WhatsApp Voice Message Status")