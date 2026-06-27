"""MVC controllers coordinating views and models."""

from app.controllers.app_controller import AppController
from app.controllers.dashboard_controller import DashboardController
from app.controllers.project_controller import ProjectController

__all__ = ["AppController", "DashboardController", "ProjectController"]
