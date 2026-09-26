echo "Copying Nginx web page into container..."

sudo cp \
    "$PROJECT_DIR/config/nginx/index.html" \
    "$MERGED/var/www/localhost/htdocs/index.html"
