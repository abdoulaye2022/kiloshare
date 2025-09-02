'use client';

import React from 'react';

interface ChartProps {
  data: Array<{ label: string; value: number; color?: string }>;
  title: string;
  type?: 'bar' | 'pie' | 'line';
  height?: number;
}

export const BarChart = ({ data, title, height = 200 }: ChartProps) => {
  const maxValue = Math.max(...data.map(d => d.value));

  return (
    <div className="bg-white p-6 rounded-lg border border-gray-200">
      <h3 className="text-lg font-semibold text-gray-900 mb-4">{title}</h3>
      <div className="space-y-3" style={{ height: `${height}px` }}>
        {data.map((item, index) => {
          const percentage = maxValue > 0 ? (item.value / maxValue) * 100 : 0;
          const color = item.color || '#3B82F6';
          
          return (
            <div key={index} className="flex items-center space-x-3">
              <div className="w-24 text-sm font-medium text-gray-700 text-right">
                {item.label}
              </div>
              <div className="flex-1 bg-gray-100 rounded-full h-6 relative overflow-hidden">
                <div
                  className="h-full rounded-full transition-all duration-500 flex items-center justify-end pr-2"
                  style={{
                    width: `${Math.max(percentage, 2)}%`,
                    backgroundColor: color
                  }}
                >
                  <span className="text-xs font-medium text-gray-100">
                    {item.value}
                  </span>
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};

export const PieChart = ({ data, title }: ChartProps) => {
  const total = data.reduce((sum, item) => sum + item.value, 0);
  let currentAngle = 0;

  const colors = [
    '#3B82F6', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6', 
    '#06B6D4', '#84CC16', '#F97316', '#EC4899', '#6366F1'
  ];

  return (
    <div className="bg-white p-6 rounded-lg border border-gray-200">
      <h3 className="text-lg font-semibold text-gray-900 mb-4">{title}</h3>
      <div className="flex items-center space-x-6">
        {/* Pie Chart */}
        <div className="relative">
          <svg width="200" height="200" viewBox="0 0 200 200" className="transform -rotate-90">
            {data.map((item, index) => {
              const percentage = total > 0 ? item.value / total : 0;
              const angle = percentage * 360;
              const color = item.color || colors[index % colors.length];
              
              // Create arc path
              const startAngle = (currentAngle * Math.PI) / 180;
              const endAngle = ((currentAngle + angle) * Math.PI) / 180;
              
              const largeArcFlag = angle > 180 ? 1 : 0;
              const x1 = 100 + 80 * Math.cos(startAngle);
              const y1 = 100 + 80 * Math.sin(startAngle);
              const x2 = 100 + 80 * Math.cos(endAngle);
              const y2 = 100 + 80 * Math.sin(endAngle);
              
              const pathData = [
                `M 100 100`,
                `L ${x1} ${y1}`,
                `A 80 80 0 ${largeArcFlag} 1 ${x2} ${y2}`,
                'Z'
              ].join(' ');
              
              currentAngle += angle;
              
              return (
                <path
                  key={index}
                  d={pathData}
                  fill={color}
                  stroke="#f3f4f6"
                  strokeWidth="2"
                  className="hover:opacity-80 transition-opacity cursor-pointer"
                  title={`${item.label}: ${item.value} (${(percentage * 100).toFixed(1)}%)`}
                />
              );
            })}
          </svg>
          <div className="absolute inset-0 flex items-center justify-center">
            <div className="text-center">
              <div className="text-2xl font-bold text-gray-900">{total}</div>
              <div className="text-sm text-gray-500">Total</div>
            </div>
          </div>
        </div>

        {/* Legend */}
        <div className="flex-1 space-y-2">
          {data.map((item, index) => {
            const percentage = total > 0 ? (item.value / total) * 100 : 0;
            const color = item.color || colors[index % colors.length];
            
            return (
              <div key={index} className="flex items-center space-x-3">
                <div
                  className="w-4 h-4 rounded-full"
                  style={{ backgroundColor: color }}
                />
                <div className="flex-1 flex justify-between">
                  <span className="text-sm font-medium text-gray-700">
                    {item.label}
                  </span>
                  <div className="text-right">
                    <div className="text-sm font-bold text-gray-900">
                      {item.value}
                    </div>
                    <div className="text-xs text-gray-500">
                      {percentage.toFixed(1)}%
                    </div>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};

export const LineChart = ({ data, title, height = 200 }: ChartProps) => {
  const maxValue = Math.max(...data.map(d => d.value));
  const minValue = Math.min(...data.map(d => d.value));
  const range = maxValue - minValue;

  return (
    <div className="bg-white p-6 rounded-lg border border-gray-200">
      <h3 className="text-lg font-semibold text-gray-900 mb-4">{title}</h3>
      <div className="relative" style={{ height: `${height}px` }}>
        <svg width="100%" height="100%" className="overflow-visible">
          {/* Grid lines */}
          {[0, 0.25, 0.5, 0.75, 1].map((ratio, index) => (
            <line
              key={index}
              x1="0"
              y1={`${ratio * 100}%`}
              x2="100%"
              y2={`${ratio * 100}%`}
              stroke="#E5E7EB"
              strokeWidth="1"
              strokeDasharray="2,2"
            />
          ))}

          {/* Line */}
          <polyline
            points={data
              .map((item, index) => {
                const x = (index / (data.length - 1)) * 100;
                const y = range > 0 ? (1 - (item.value - minValue) / range) * 100 : 50;
                return `${x}%,${y}%`;
              })
              .join(' ')}
            fill="none"
            stroke="#3B82F6"
            strokeWidth="3"
            strokeLinecap="round"
            strokeLinejoin="round"
            className="drop-shadow-sm"
          />

          {/* Points */}
          {data.map((item, index) => {
            const x = (index / (data.length - 1)) * 100;
            const y = range > 0 ? (1 - (item.value - minValue) / range) * 100 : 50;
            
            return (
              <circle
                key={index}
                cx={`${x}%`}
                cy={`${y}%`}
                r="4"
                fill="#3B82F6"
                stroke="#f3f4f6"
                strokeWidth="2"
                className="hover:r-6 transition-all cursor-pointer"
                title={`${item.label}: ${item.value}`}
              />
            );
          })}
        </svg>

        {/* Labels */}
        <div className="absolute bottom-0 left-0 right-0 flex justify-between mt-2">
          {data.map((item, index) => (
            <div key={index} className="text-xs text-gray-500 text-center">
              {item.label}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

// Composant de métriques rapides
export const MetricCard = ({
  title,
  value,
  change,
  icon,
  color = 'blue',
  format = 'number'
}: {
  title: string;
  value: number | string;
  change?: { value: number; isPositive: boolean; period: string };
  icon: React.ReactNode;
  color?: 'blue' | 'green' | 'orange' | 'red' | 'purple';
  format?: 'number' | 'currency' | 'percentage';
}) => {
  const colorClasses = {
    blue: 'bg-blue-50 border-blue-200 text-blue-900',
    green: 'bg-green-50 border-green-200 text-green-900',
    orange: 'bg-orange-50 border-orange-200 text-orange-900',
    red: 'bg-red-50 border-red-200 text-red-900',
    purple: 'bg-purple-50 border-purple-200 text-purple-900',
  };

  const formatValue = (val: number | string) => {
    if (typeof val === 'string') return val;
    switch (format) {
      case 'currency':
        return new Intl.NumberFormat('fr-CA', { style: 'currency', currency: 'CAD' }).format(val);
      case 'percentage':
        return `${val.toFixed(1)}%`;
      default:
        return new Intl.NumberFormat('fr-FR').format(val);
    }
  };

  return (
    <div className={`p-6 rounded-xl border-2 ${colorClasses[color]} transition-all hover:shadow-md`}>
      <div className="flex items-center justify-between">
        <div className="flex-1">
          <p className="text-sm font-medium opacity-70 mb-1">{title}</p>
          <p className="text-3xl font-bold mb-2">
            {formatValue(value)}
          </p>
          {change && (
            <div className="flex items-center space-x-1">
              <span className={`text-sm font-medium ${change.isPositive ? 'text-green-600' : 'text-red-600'}`}>
                {change.isPositive ? '↗' : '↘'} {Math.abs(change.value)}
              </span>
              <span className="text-xs text-gray-500">{change.period}</span>
            </div>
          )}
        </div>
        <div className="text-4xl opacity-20">
          {icon}
        </div>
      </div>
    </div>
  );
};

// Composant de tableau de données
export const DataTable = ({ 
  data, 
  columns,
  title 
}: { 
  data: any[]; 
  columns: Array<{ key: string; label: string; format?: (value: any) => string }>;
  title: string;
}) => {
  return (
    <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
      <div className="px-6 py-4 bg-gray-50 border-b border-gray-200">
        <h3 className="text-lg font-semibold text-gray-900">{title}</h3>
      </div>
      <div className="overflow-x-auto">
        <table className="w-full">
          <thead className="bg-gray-50">
            <tr>
              {columns.map((column) => (
                <th key={column.key} className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  {column.label}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {data.map((row, index) => (
              <tr key={index} className="hover:bg-gray-50">
                {columns.map((column) => (
                  <td key={column.key} className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    {column.format ? column.format(row[column.key]) : row[column.key]}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};