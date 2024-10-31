#!/bin/bash
# deploy.sh

# Configuration
REMOTE_USER="root"
REMOTE_HOST="172.105.73.77"
REMOTE_PATH="/"
APP_NAME="app"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Starting deployment...${NC}"

# Build Docker image locally
echo "Building Docker image..."
docker build -t $APP_NAME:latest .

# Save image to file
echo "Saving Docker image..."
docker save $APP_NAME:latest | gzip > deploy-image.tar.gz

# Upload Docker image to server
echo "Uploading Docker image to server..."
scp deploy-image.tar.gz $REMOTE_USER@$REMOTE_HOST:/tmp/

# Upload docker-compose file
scp docker-compose.yml $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/

# Execute deployment commands on server
ssh $REMOTE_USER@$REMOTE_HOST << 'ENDSSH'
    cd /tmp
    # Load Docker image
    docker load < deploy-image.tar.gz
    rm deploy-image.tar.gz

    # Go to project directory
    cd $REMOTE_PATH

    # Backup database
    docker-compose exec -T db mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" laravel > backup.sql

    # Take down existing containers
    docker-compose down

    # Start new containers
    docker-compose up -d

    # Run migrations
    docker-compose exec -T app php artisan migrate --force
ENDSSH

# Clean up local deploy image
rm deploy-image.tar.gz

echo -e "${GREEN}Deployment completed!${NC}"