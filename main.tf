terraform {
  required_providers {
    google = ">= 4.0.0"
  }
}

data "google_project" "project" {

}

provider "google" {
  project = "terraform-gcp-example-356006"
}

# Enables the Cloud Run API
resource "google_project_service" "run_api" {
  service = "run.googleapis.com"
}

resource "google_project_service" "cloudbuild_api" {
  service = "cloudbuild.googleapis.com"
}

# Create the Cloud Run service
resource "google_cloud_run_service" "app" {
  name = "app"
  location = "europe-north1"

  template {
    spec {
      containers {
        image = "gcr.io/google-samples/hello-app:1.0"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  # Waits for the Cloud Run API to be enabled
  depends_on = [google_project_service.run_api]
}

# Allow unauthenticated users to invoke the service
data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  location    = google_cloud_run_service.app.location
  project     = google_cloud_run_service.app.project
  service     = google_cloud_run_service.app.name

  policy_data = data.google_iam_policy.noauth.policy_data
}

# Cloudbuild
resource "google_cloudbuild_trigger" "trigger" {
  github {
    owner = "jmerilainen"
    name  = "terraform-gcp-example"
    push {
      branch = "^main$"
    }
  }

  filename        = "cloudbuild.yaml"
  depends_on = [
    google_project_iam_member.act_as,
    google_project_service.cloudbuild_api
  ]
}

data "google_iam_policy" "cloudrun_admin" {
  binding {
    role = "roles/run.admin"
    members = [
      "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com",
    ]
  }
}

resource "google_project_iam_member" "act_as" {
  project = data.google_project.project.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

resource "google_cloud_run_service_iam_policy" "policy" {
  location    = google_cloud_run_service.app.location
  project     = google_cloud_run_service.app.project
  service     = google_cloud_run_service.app.name

  policy_data = data.google_iam_policy.cloudrun_admin.policy_data
}
