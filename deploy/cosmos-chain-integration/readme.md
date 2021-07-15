

1) build "tmkms/Dockerfile" to get artifacts from it.
```
docker build --progress=plain -t onomy/tmkms-builder:local  -f ../../Dockerfile ../../
```
2) build tmkms container
```
docker build --progress=plain -t onomy/tmkms:local  -f Dockerfile ../../
```
3) run
```
docker docker-compose.yml
```