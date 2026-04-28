const uploadImage = (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ message: 'No file uploaded' });
        }

        const relativePath = `uploads/${req.file.filename}`;

        return res.status(200).json({
            message: 'Image uploaded successfully',
            path: relativePath
        });
    } catch (error) {
        return res.status(500).json({ message: 'Server error during upload', error: error.message });
    }
};

module.exports = { uploadImage };