import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8080/api/v1';

export async function PUT(request: NextRequest) {
  try {
    const authHeader = request.headers.get('authorization');
    const body = await request.json();
    const { id, ...updateData } = body;
    
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
    const response = await fetch(`${BACKEND_URL}/trips/${id}/update`, {
      method: 'PUT',
      headers: {
        'Authorization': authHeader,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(updateData),
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