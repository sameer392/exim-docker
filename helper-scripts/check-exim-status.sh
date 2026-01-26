#!/bin/bash
# Script to check Exim mail server status

CONTAINER_NAME="exim-mailserver"

echo "========================================="
echo "Exim Mail Server Status Check"
echo "========================================="
echo ""

# Check if container is running
echo "1. Container Status:"
if docker ps | grep -q "$CONTAINER_NAME"; then
    echo "   ✅ Container is running"
    docker ps | grep "$CONTAINER_NAME"
else
    echo "   ❌ Container is not running"
    exit 1
fi
echo ""

# Check Exim process
echo "2. Exim Process:"
if docker exec "$CONTAINER_NAME" ps aux | grep -q "[e]xim4"; then
    echo "   ✅ Exim daemon is running"
    docker exec "$CONTAINER_NAME" ps aux | grep "[e]xim4"
else
    echo "   ❌ Exim daemon is not running"
fi
echo ""

# Check Exim version
echo "3. Exim Version:"
docker exec "$CONTAINER_NAME" exim4 -bV 2>&1 | head -3
echo ""

# Check listening ports
echo "4. Listening Ports:"
if docker exec "$CONTAINER_NAME" netstat -tlnp 2>/dev/null | grep -E ":25|:587|:465"; then
    echo "   ✅ Ports are listening"
elif docker exec "$CONTAINER_NAME" ss -tlnp 2>/dev/null | grep -E ":25|:587|:465"; then
    echo "   ✅ Ports are listening"
else
    echo "   ⚠️  Could not check ports (netstat/ss not available)"
fi
echo ""

# Check mail queue
echo "5. Mail Queue:"
QUEUE_COUNT=$(docker exec "$CONTAINER_NAME" exim4 -bpc 2>/dev/null || echo "0")
if [ "$QUEUE_COUNT" = "0" ]; then
    echo "   ✅ Queue is empty ($QUEUE_COUNT messages)"
else
    echo "   ⚠️  Queue has $QUEUE_COUNT messages"
    echo "   Recent queue items:"
    docker exec "$CONTAINER_NAME" exim4 -bp 2>&1 | head -10
fi
echo ""

# Check recent logs
echo "6. Recent Logs (last 5 lines):"
docker logs "$CONTAINER_NAME" --tail 5 2>&1
echo ""

# Check password file
echo "7. Password File:"
if docker exec "$CONTAINER_NAME" test -f /etc/exim4/passwd; then
    echo "   ✅ Password file exists"
    docker exec "$CONTAINER_NAME" cat /etc/exim4/passwd | head -3
else
    echo "   ❌ Password file not found"
fi
echo ""

# Check configuration
echo "8. Configuration Test:"
if docker exec "$CONTAINER_NAME" exim4 -bV >/dev/null 2>&1; then
    echo "   ✅ Configuration is valid"
else
    echo "   ❌ Configuration has errors"
    docker exec "$CONTAINER_NAME" exim4 -bV 2>&1 | tail -5
fi
echo ""

echo "========================================="
echo "Status Check Complete"
echo "========================================="
