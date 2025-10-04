import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8080/api/v1';

export async function POST(request: NextRequest) {
  try {
    
    const body = await request.json();
    const { id, reason } = body;
    const authHeader = request.headers.get('authorization');
    
    
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
    
    const response = await fetch(`${BACKEND_URL}/admin/trips/${id}/reject`, {
      method: 'POST',
      headers: {
        'Authorization': authHeader,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ reason: reason || 'No reason provided' }),
    });

    const data = await response.json();

    // Return the backend response
    return NextResponse.json(data, { status: response.status });

  } catch (error) {
    console.error('Proxy error:', error);
    return NextResponse.json(
      { success: false, message: 'Internal server error' },
      { status: 500 }
    );
  }
}