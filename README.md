# Observer Repository

This repository contains the `observer_frontend` and `observer_backend` projects as submodules.

## Cloning the Repository

To clone this repository along with its submodules, use the following command:

```bash
git clone --recurse-submodules git@github.com:kbjohnson-penn/observer.git
```

If you have already cloned the repository without submodules, you can initialize and update the submodules with:

```bash
git submodule update --init --recursive
```

## Submodules

### Observer Frontend

The `observer_frontend` submodule contains the frontend code for the Observer project.

### Observer Backend

The `observer_backend` submodule contains the backend code for the Observer project.

## Updating Submodules

To update the submodules to the latest commit from their respective repositories, use the following command:

```bash
git submodule update --remote --merge
```

## Running the Project using Docker Compose

To run the entire project using Docker Compose, follow these steps:

1. Navigate to the parent directory:

   ```bash
   cd observer
   ```

2. Build and start the Docker containers:

   ```bash
   docker-compose up --build -d
   ```

3. Create a Django superuser: Open a new terminal and run the following command:

   ```bash
   docker-compose exec backend python manage.py createsuperuser
   ```

4. Access the services:

   **Frontend**: Open your web browser and navigate to `http://localhost:3000`

   **Backend**: Open your web browser and navigate to `http://localhost:8000/admin` to access the Django admin interface

5. Stopping the containers: To stop the running containers, use:

   ```bash
   docker-compose down
   ```

This will build and start the Docker containers for both the frontend and backend services, create a Django superuser, and provide access to the services.
