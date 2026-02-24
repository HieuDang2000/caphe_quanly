<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\File;

Route::get('/', function () {
    $indexPath = public_path('flutter/index.html');

    if (! File::exists($indexPath)) {
        abort(404, 'Flutter web build not found. Please run "flutter build web" and copy to api/public/flutter.');
    }

    return response(File::get($indexPath), 200)
        ->header('Content-Type', 'text/html');
});

Route::get('/{any}', function () {
    $indexPath = public_path('flutter/index.html');

    if (! File::exists($indexPath)) {
        abort(404, 'Flutter web build not found. Please run "flutter build web" and copy to api/public/flutter.');
    }

    return response(File::get($indexPath), 200)
        ->header('Content-Type', 'text/html');
})->where('any', '.*');
