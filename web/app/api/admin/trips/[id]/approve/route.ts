import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8080/api/v1';

export async function POST(request: NextRequest, context: { params: Promise<{ id: string }> }) {
  try {
    console.log('🚀 Admin Approve API called');
    const params = await context.params;
    console.log('🔢 Trip ID:', params?.id);
    
    const { id } = params;
    const authHeader = request.headers.get('authorization');
    
    if (!authHeader) {
      return NextResponse.json(
        { success: false, message: 'Authorization header required' },
        { status: 401 }
      );
    }

    // Forward the request to the backend
    const response = await fetch(`${BACKEND_URL}/admin/trips/${id}/approve`, {
      method: 'POST',
      headers: {
        'Authorization': authHeader,
        'Content-Type': 'application/json',
      },
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