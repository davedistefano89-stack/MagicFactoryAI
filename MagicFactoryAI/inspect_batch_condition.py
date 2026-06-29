import os
import sys

sys.path.insert(0, os.getcwd())

from PySide6.QtWidgets import QApplication
from app.controllers.app_controller import AppController
from core.ai.models import AIRequest
from ui.widgets.workspace.tabs.ai_generator_tab import _BatchExecutionWorker

app = AppController.instance()
qapp = QApplication.instance() or QApplication([])
output_dir = os.path.join(os.getcwd(), 'data', 'library')
os.makedirs(output_dir, exist_ok=True)

request = AIRequest(
    image_path=output_dir,
    prompt='verify batch callback',
    provider='mock',
    model='mock',
    width=1024,
    height=1024,
    quality='high',
    output_format='png',
    category='Test',
)

task = app.batch_controller.create_task(
    name='verify',
    request=request,
    project_id=1,
    output_directory=output_dir,
    category_id=None,
    prompt_id=None,
)

worker = _BatchExecutionWorker(app.batch_controller, app.ai_generator, total_tasks=1)
app.batch_controller.execute(task, on_result=worker._on_result, on_progress=worker._on_progress)
