'use client';

import React, { useState, useCallback } from 'react';
import { Upload, X, ImageIcon, AlertCircle, CheckCircle } from 'lucide-react';

interface ImageUploadProps {
  tripId?: number;
  existingImages?: string[];
  onImagesChange?: (images: string[]) => void;
  maxImages?: number;
  maxFileSize?: number; // en MB
  className?: string;
}

interface UploadedImage {
  id: string;
  url: string;
  name: string;
  uploading?: boolean;
  error?: string;
}

export default function ImageUpload({ 
  tripId, 
  existingImages = [], 
  onImagesChange,
  maxImages = 5,
  maxFileSize = 5,
  className = ""
}: ImageUploadProps) {
  const [images, setImages] = useState<UploadedImage[]>(
    existingImages.map((url, index) => ({
      id: `existing-${index}`,
      url,
      name: `Image ${index + 1}`
    }))
  );
  const [isDragging, setIsDragging] = useState(false);
  const [uploadProgress, setUploadProgress] = useState<{ [key: string]: number }>({});

  const uploadToCloudinary = async (file: File): Promise<string> => {
    const formData = new FormData();
    formData.append('file', file);

    const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8080'}/api/v1/trips/${tripId}/cloudinary-images`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${localStorage.getItem('auth_token')}`
      },
      body: formData
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.message || 'Échec de l\'upload');
    }

    const result = await response.json();
    return result.data?.image_url || result.url;
  };

  const handleFileSelect = useCallback(async (files: FileList) => {
    const newFiles = Array.from(files);
    
    // Vérifications
    if (images.length + newFiles.length > maxImages) {
      alert(`Vous ne pouvez ajouter que ${maxImages} images maximum`);
      return;
    }

    for (const file of newFiles) {
      // Vérifier le type de fichier
      if (!file.type.startsWith('image/')) {
        alert(`${file.name} n'est pas une image valide`);
        continue;
      }

      // Vérifier la taille
      if (file.size > maxFileSize * 1024 * 1024) {
        alert(`${file.name} est trop volumineux (max ${maxFileSize}MB)`);
        continue;
      }

      // Créer un preview temporaire
      const tempId = `temp-${Date.now()}-${Math.random()}`;
      const tempUrl = URL.createObjectURL(file);
      
      const newImage: UploadedImage = {
        id: tempId,
        url: tempUrl,
        name: file.name,
        uploading: true
      };

      setImages(prev => [...prev, newImage]);

      try {
        // Upload vers Cloudinary
        const cloudinaryUrl = await uploadToCloudinary(file);
        
        setImages(prev => prev.map(img => 
          img.id === tempId 
            ? { ...img, url: cloudinaryUrl, uploading: false }
            : img
        ));

        // Nettoyer l'URL temporaire
        URL.revokeObjectURL(tempUrl);

      } catch (error) {
        console.error('Erreur upload:', error);
        setImages(prev => prev.map(img => 
          img.id === tempId 
            ? { ...img, uploading: false, error: error instanceof Error ? error.message : 'Erreur inconnue' }
            : img
        ));
      }
    }
  }, [images, maxImages, maxFileSize, tripId]);

  const removeImage = async (imageId: string) => {
    const imageToRemove = images.find(img => img.id === imageId);
    
    if (imageToRemove && tripId && !imageToRemove.id.startsWith('temp-')) {
      try {
        // Supprimer de l'API si ce n'est pas une image temporaire
        await fetch(`${process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8080'}/api/v1/trips/${tripId}/images/${imageId}`, {
          method: 'DELETE',
          headers: {
            'Authorization': `Bearer ${localStorage.getItem('auth_token')}`
          }
        });
      } catch (error) {
        console.error('Erreur lors de la suppression:', error);
        alert('Erreur lors de la suppression de l\'image');
        return;
      }
    }

    setImages(prev => prev.filter(img => img.id !== imageId));
    
    // Notifier le composant parent
    if (onImagesChange) {
      const updatedUrls = images.filter(img => img.id !== imageId).map(img => img.url);
      onImagesChange(updatedUrls);
    }
  };

  const handleDrag = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === 'dragenter' || e.type === 'dragover') {
      setIsDragging(true);
    } else if (e.type === 'dragleave') {
      setIsDragging(false);
    }
  }, []);

  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragging(false);
    
    if (e.dataTransfer.files) {
      handleFileSelect(e.dataTransfer.files);
    }
  }, [handleFileSelect]);

  return (
    <div className={`space-y-4 ${className}`}>
      {/* Zone de drop */}
      <div
        className={`border-2 border-dashed rounded-lg p-6 text-center transition-colors ${
          isDragging
            ? 'border-blue-400 bg-blue-50'
            : 'border-gray-300 hover:border-gray-400'
        }`}
        onDragEnter={handleDrag}
        onDragOver={handleDrag}
        onDragLeave={handleDrag}
        onDrop={handleDrop}
      >
        <ImageIcon className="mx-auto h-12 w-12 text-gray-400 mb-4" />
        <div className="space-y-2">
          <p className="text-lg font-medium text-gray-900">
            Ajoutez des images à votre annonce
          </p>
          <p className="text-sm text-gray-500">
            Glissez-déposez vos images ici, ou cliquez pour sélectionner
          </p>
          <p className="text-xs text-gray-400">
            Format supporté: JPG, PNG, GIF • Max {maxFileSize}MB par image • {maxImages} images max
          </p>
        </div>
        
        <label className="mt-4 inline-block">
          <input
            type="file"
            multiple
            accept="image/*"
            onChange={(e) => e.target.files && handleFileSelect(e.target.files)}
            className="hidden"
          />
          <span className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg cursor-pointer inline-flex items-center space-x-2 transition-colors">
            <Upload className="h-4 w-4" />
            <span>Sélectionner des images</span>
          </span>
        </label>
      </div>

      {/* Preview des images */}
      {images.length > 0 && (
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
          {images.map((image) => (
            <div key={image.id} className="relative group">
              <div className="aspect-square rounded-lg overflow-hidden bg-gray-100">
                <img
                  src={image.url}
                  alt={image.name}
                  className={`w-full h-full object-cover transition-opacity ${
                    image.uploading ? 'opacity-50' : 'opacity-100'
                  }`}
                />
                
                {/* Overlay de chargement */}
                {image.uploading && (
                  <div className="absolute inset-0 flex items-center justify-center bg-black bg-opacity-50">
                    <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-white"></div>
                  </div>
                )}

                {/* Overlay d'erreur */}
                {image.error && (
                  <div className="absolute inset-0 flex items-center justify-center bg-red-500 bg-opacity-75">
                    <AlertCircle className="h-6 w-6 text-white" />
                  </div>
                )}

                {/* Overlay de succès */}
                {!image.uploading && !image.error && (
                  <div className="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity">
                    <CheckCircle className="h-5 w-5 text-green-500 bg-white rounded-full" />
                  </div>
                )}

                {/* Bouton de suppression */}
                {!image.uploading && (
                  <button
                    onClick={() => removeImage(image.id)}
                    className="absolute top-2 left-2 bg-red-500 hover:bg-red-600 text-white rounded-full p-1 opacity-0 group-hover:opacity-100 transition-opacity"
                  >
                    <X className="h-3 w-3" />
                  </button>
                )}
              </div>
              
              {/* Nom du fichier */}
              <p className="mt-2 text-xs text-gray-600 truncate" title={image.name}>
                {image.name}
              </p>
              
              {/* Message d'erreur */}
              {image.error && (
                <p className="mt-1 text-xs text-red-600" title={image.error}>
                  Erreur: {image.error}
                </p>
              )}
            </div>
          ))}
        </div>
      )}

      {/* Compteur d'images */}
      <div className="text-center text-sm text-gray-500">
        {images.length} / {maxImages} images
      </div>
    </div>
  );
}