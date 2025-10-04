import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8080';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { id, reason } = body;
    const authHeader = request.headers.get('authorization');

    console.log('🔍 Reject trip request - ID:', id, 'Reason:', reason);

    if (!authHeader) {
      return NextResponse.json(
        { success: false, message: 'Authorization header required' },
        { status: 401 }
      );
    }

    if (!id) {
      return NextResponse.json(
        { success: false, message: 'Trip ID is required' },
        { status: 400 }
      );
    }

    // Forward the request to the backend
    const backendUrl = `${BACKEND_URL}/api/v1/admin/trips/reject`;
    console.log('🔍 Calling backend:', backendUrl, 'with body:', { id, reason });

    const response = await fetch(backendUrl, {
      method: 'POST',
      headers: {
        'Authorization': authHeader,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        id,
        reason: reason || 'No reason provided'
      }),
    });

    console.log('🔍 Backend response status:', response.status);

    const data = await response.json();
    console.log('🔍 Backend response data:', data);

    // Return the backend response
    return NextResponse.json(data, { status: response.status });

  } catch (error) {
    console.error('❌ Proxy error:', error);
    return NextResponse.json(
      { success: false, message: 'Internal server error' },
      { status: 500 }
    );
  }
}