const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/authMiddleware');
const supabase = require('../config/supabase');

// @route   GET /api/files/signed-url
// @desc    Generate a secure upload or download URL from Supabase Storage
router.post('/signed-url', authMiddleware, async (req, res) => {
  const { filename, action } = req.body; 
  // action: 'read' or 'write'

  try {
    let signedUrlObject;
    
    if (action === 'write') {
        // Generates an upload URL allowing the frontend to push directly to Supabase Bucket
        const { data, error } = await supabase
            .storage
            .from('internal_docs')
            .createSignedUploadUrl(filename);
            
        if (error) throw error;
        signedUrlObject = data;
    } else {
        // Generate download URL valid for 60 seconds
        const { data, error } = await supabase
            .storage
            .from('internal_docs')
            .createSignedUrl(filename, 60);
            
        if (error) throw error;
        signedUrlObject = data;
    }

    res.json({ url: signedUrlObject.signedUrl, filename: signedUrlObject.path });
  } catch (err) {
    console.error(err);
    res.status(500).send('Server error generating Supabase signed URL');
  }
});

module.exports = router;
