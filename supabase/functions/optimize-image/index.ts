import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import Sharp from 'https://esm.sh/sharp@0.32.6'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { imageData } = await req.json()
    if (!imageData) throw new Error('Image data is required')

    // Convert base64 to buffer
    const buffer = Uint8Array.from(atob(imageData.split(',')[1]), c => c.charCodeAt(0))

    // Process image with Sharp
    const processedBuffer = await Sharp(buffer)
      .resize(720, 720, {
        fit: 'inside',
        withoutEnlargement: true
      })
      .webp({ // Convert to WebP format
        quality: 80,
        effort: 4 // Balance between compression speed and quality
      })
      .toBuffer()

    // Convert back to base64
    const base64 = btoa(String.fromCharCode(...new Uint8Array(processedBuffer)))
    const optimizedDataUrl = `data:image/webp;base64,${base64}`

    return new Response(
      JSON.stringify({ url: optimizedDataUrl }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})