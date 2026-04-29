const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');

// @route   POST /api/auth/login
// @desc    Authenticate user & get JWT token using PostgreSQL
router.post('/login', async (req, res) => {
  const { email, password, deviceId } = req.body;

  try {
    let { data: user, error } = await supabase
        .from('users')
        .select('*')
        .or(`email.eq.${email},company_email.eq.${email}`)
        .single();

    if (error || !user) return res.status(400).json({ message: 'Invalid Credentials' });

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) return res.status(400).json({ message: 'Invalid Credentials' });

    // Device Binding Security (For non-admins)
    if (!user.is_admin) {
      if (!user.device_id) {
        // First time login - bind the device
        const { error: updateError } = await supabase
            .from('users')
            .update({ device_id: deviceId })
            .eq('id', user.id);
            
        if (updateError) throw updateError;
      } else if (user.device_id !== deviceId) {
        return res.status(403).json({ message: 'Unauthorized Device. This account is bound to another phone.' });
      }
    }

    const payload = {
      user: {
        id: user.id,
        roleId: user.role_id,
        isAdmin: user.is_admin,
        faceRegistered: !!user.face_embedding && user.face_embedding.length > 0
      }
    };

    jwt.sign(
      payload,
      process.env.JWT_SECRET,
      { expiresIn: '12h' },
      (err, token) => {
        if (err) throw err;
        res.json({ token, user: { roleId: user.role_id, name: user.name, isAdmin: user.is_admin, faceRegistered: !!user.face_embedding && user.face_embedding.length > 0 } });
      }
    );
  } catch (err) {
    console.error(err);
    res.status(500).send('Server error');
  }
});

// @route   POST /api/auth/biometric
// @desc    Verify face embedding using Cosine Similarity natively in Supabase PostgreSQL pgvector
router.post('/biometric', async (req, res) => {
    const { roleId, currentEmbedding } = req.body; // array of 192 floats
    
    try {
        const { data: user, error: userError } = await supabase
            .from('users')
            .select('id, face_embedding')
            .eq('role_id', roleId)
            .single();

        if (userError || !user) return res.status(404).json({ message: 'User not found' });
        
        if (!user.face_embedding || user.face_embedding.length === 0) {
            // First time - store the vector formatted as string '[val1, val2...]'
            const embeddingString = `[${currentEmbedding.join(',')}]`;
            await supabase
                .from('users')
                .update({ face_embedding: embeddingString })
                .eq('id', user.id);

            return res.json({ success: true, message: 'Face pattern registered successfully.' });
        }

        // Call the custom match_face RPC function declared in our SQL schema
        const formatString = `[${currentEmbedding.join(',')}]`;
        const { data, error } = await supabase.rpc('match_face', {
            query_embedding: formatString,
            match_threshold: 0.65, // 65% cosine similarity required
            target_role_id: roleId
        });

        if (error) throw error;

        if (data && data.length > 0) {
            // Found a match exceeding the threshold!
            res.json({ success: true, score: data[0].similarity });
        } else {
            res.status(401).json({ success: false, score: 0, message: 'Face verification failed' });
        }
    } catch (err) {
        console.error(err);
        res.status(500).send('Server error');
    }
});

module.exports = router;
