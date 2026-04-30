# grocery_store_list
A Flutter app to add item to a grocery store list and transfer item not bought to another lsit and also add note to an item.


## Command to refresh backend: 
```bash
docker-compose build --no-cache && docker-compose up -d
```

## Command to install onto android phone paired to android studio
```bash
export $(grep -v '^#' .env | xargs) && flutter run --release -d $DEVICE_ID
```

## when updating models
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```