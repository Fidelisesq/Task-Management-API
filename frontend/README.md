# Task Management Frontend

A simple, clean single-page application for managing tasks.

## Features

- **User Authentication**: Register and login with JWT tokens
- **Task Management**: Create, read, update, and delete tasks
- **Task Filtering**: Filter by status (All, Pending, In Progress, Completed)
- **Priority Levels**: Low, Medium, High
- **Due Dates**: Optional due date tracking
- **Responsive Design**: Works on desktop and mobile

## Setup Instructions

### Step 1: Update API Configuration

Edit `app.js` and update the `API_BASE_URL` with your ALB DNS name:

```javascript
const API_BASE_URL = 'http://your-alb-name-123456789.us-east-1.elb.amazonaws.com';
```

### Step 2: Enable CORS on Backend

Your backend services need to allow requests from the S3/CloudFront origin. See the backend service updates in the deployment guide.

### Step 3: Deploy to S3

1. Create S3 bucket for static website hosting
2. Upload `index.html`, `styles.css`, and `app.js`
3. Enable static website hosting
4. Configure bucket policy for public read access

### Step 4: Configure CloudFront (Optional but Recommended)

1. Create CloudFront distribution pointing to S3 bucket
2. Enable HTTPS
3. Configure custom domain (optional)

## File Structure

```
frontend/
├── index.html      # Main HTML file
├── styles.css      # Styling
├── app.js          # Application logic
└── README.md       # This file
```

## Technologies Used

- **HTML5**: Structure
- **CSS3**: Styling with CSS Grid and Flexbox
- **Vanilla JavaScript**: No frameworks, pure JS
- **Fetch API**: HTTP requests to backend
- **LocalStorage**: JWT token storage

## Browser Support

- Chrome (latest)
- Firefox (latest)
- Safari (latest)
- Edge (latest)

## Security Notes

- JWT tokens are stored in localStorage
- Tokens expire after 1 hour (3600 seconds)
- All API requests include Authorization header
- CORS is configured to allow only specific origins

## Development

To test locally:

1. Update `API_BASE_URL` in `app.js`
2. Open `index.html` in a browser
3. Or use a local server: `python -m http.server 8000`

## Deployment Checklist

- [ ] Update API_BASE_URL in app.js
- [ ] Enable CORS on backend services
- [ ] Create S3 bucket
- [ ] Upload files to S3
- [ ] Enable static website hosting
- [ ] Configure bucket policy
- [ ] (Optional) Create CloudFront distribution
- [ ] Test all functionality

## Cost Estimate

- **S3 Storage**: ~$0.023/GB/month (negligible for static files)
- **S3 Requests**: ~$0.0004/1000 requests
- **CloudFront**: ~$0.085/GB transferred (first 10TB)
- **Total**: ~$1-2/month for low traffic

## Support

For issues or questions, refer to the main project documentation.
