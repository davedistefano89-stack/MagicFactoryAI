import os
import sys
from pathlib import Path

sys.path.insert(0, os.getcwd())

from PySide6.QtWidgets import QApplication
from app.controllers.app_controller import AppController
from core.ai.models import AIRequest
from ui.widgets.workspace.tabs.ai_generator_tab import _BatchExecutionWorker

app = AppController.instance()
qapp = QApplication.instance() or QApplication([])

output_dir = Path(r'C:\Users\daved\OneDrive\Desktop\Magic Universe\MagicFactoryAI\data\library')
output_dir.mkdir(parents=True, exist_ok=True)

before = app.db.connect().execute('SELECT COUNT(*) AS cnt FROM assets').fetchone()[0]

flags = {
    'on_result': False,
    'create_asset_from_bytes': False,
    'asset_repo_create': False,
    'asset_repo_commit': False,
}

orig_create_asset = app.ai_generator.create_asset_from_bytes

def wrapped_create_asset(*args, **kwargs):
    flags['create_asset_from_bytes'] = True
    return orig_create_asset(*args, **kwargs)

app.ai_generator.create_asset_from_bytes = wrapped_create_asset

orig_repo_create = app.assets.create

def wrapped_repo_create(asset):
    flags['asset_repo_create'] = True
    return orig_repo_create(asset)

app.assets.create = wrapped_repo_create

worker = _BatchExecutionWorker(app.batch_controller, app.ai_generator, total_tasks=1)
orig_on_result = worker._on_result

def wrapped_on_result(req, result, task):
    flags['on_result'] = True
    return orig_on_result(req, result, task)

worker._on_result = wrapped_on_result

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

worker.run([task])

after = app.db.connect().execute('SELECT COUNT(*) AS cnt FROM assets').fetchone()[0]
flags['asset_repo_commit'] = after > before

print({'before': before, 'after': after, 'flags': flags})
