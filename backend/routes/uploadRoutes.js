const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const { uploadImage } = require('../controllers/uploadController');

const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, 'public/uploads/');
    },
    filename: (req, file, cb) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, uniqueSuffix + path.extname(file.originalname));
    }
});

const fileFilter = (req, file, cb) => {
    console.log(`📁 Incoming file: ${file.originalname} | MIME: ${file.mimetype}`);

    if (file.mimetype.startsWith('image/') ||
        file.originalname.match(/\.(jpg|jpeg|png|gif)$/i)) {
        cb(null, true);
    } else {
        cb(new Error('Only image files are allowed!'), false);
    }
};

const upload = multer({
    storage: storage,
    fileFilter: fileFilter,
    limits: { fileSize: 5 * 1024 * 1024 }
});

// Route: POST /api/upload
router.post('/', upload.single('file'), uploadImage);

module.exports = router;